import Foundation
import COR
import Metal
import MetalPerformanceShadersGraph

/// `Train ppo` — the stronger learner over the same collection, reward, and
/// curriculum machinery as `Train rl` (all reused from `RLTrainer`). Three
/// upgrades, each aimed at a failure class the REINFORCE runs exposed:
///
///   PPO-clip        the per-sample importance ratio is clipped at 1±ε, so a
///                   sample whose probability has already moved that far
///                   contributes no further gradient — per-iteration policy
///                   movement is bounded in distribution space, where the
///                   REINFORCE runs had to keep windows × lr under a hand-tuned
///                   displacement invariant (update shock: runs 4/5/10).
///   value baseline  A(s_t) = R − V(s_t) from the (finally trained) value
///                   head. V sees prestige/tier/baseLevel in the observation
///                   globals, so it learns the matchup correction per state —
///                   replacing the stratified LOO baseline whose ~4-episode
///                   strata were noise (run 8), and the length-normalization
///                   hack (timeout episodes converge to V ≈ R ⇒ A ≈ 0).
///   KL anchor       β · KL(π‖π_ref) per head toward the frozen starting
///                   weights, full-distribution, against an in-graph constant
///                   copy of the network — the policy can improve on the BC
///                   prior but cannot silently unlearn it (kiting: runs 2/3).
///
/// Old log-probs come from a *read pass*, not collection-time recording: the
/// episode batch replays through the graph once with the iteration's starting
/// weights (= the collection weights), caching per-sample joint log-prob and
/// value per window ordinal. `Batcher` is deterministic in episode mode, so
/// every subsequent epoch pass produces byte-identical windows (asserted
/// against the cache) — and the runaway-turn-guard steps that collection
/// never forward-passed get their log-prob from the same graph math the
/// update sees, so ratios stay exact by construction.
enum PPOTrainer {

	struct Config {
		var epochs = 3
		var clip: Float = 0.2
		var vcoef: Float = 0.5
		var kl: Float = 0.1
		var ent: Float = 0
		var temp: Float = 1
	}

	static func run(_ args: [String]) throws {
		var weightsPath: String?
		var refPath: String?
		var out = "tmp/runs/ppo"
		var iters = 100
		var episodes = 32
		var b = 16
		var t = 16
		var lr: Float = 5e-6
		var seed = 1000
		var ckpt = 10
		var evalN = 8
		var curriculum: Float = 0
		var anneal: Float = 0.30
		var suite: RolloutSuite = .mixed
		var vwarm = 5
		var lam: Float = 1
		var cfg = Config()

		try Args(args).parse { flag, next in
			switch flag {
			case "--weights": weightsPath = try next()
			case "--ref": refPath = try next()
			case "--out": out = try next()
			case "--iters": iters = try Int(next()) ?? iters
			case "--episodes": episodes = try Int(next()) ?? episodes
			case "--b": b = try Int(next()) ?? b
			case "--t": t = try Int(next()) ?? t
			case "--lr": lr = try Float(next()) ?? lr
			case "--temp": cfg.temp = try Float(next()) ?? cfg.temp
			case "--seed": seed = try Int(next()) ?? seed
			case "--ckpt": ckpt = try Int(next()) ?? ckpt
			case "--evaln": evalN = try Int(next()) ?? evalN
			case "--curriculum": curriculum = try Float(next()) ?? curriculum
			case "--anneal": anneal = try Float(next()) ?? anneal
			case "--suite": suite = try .parse(next())
			case "--epochs": cfg.epochs = try Int(next()) ?? cfg.epochs
			case "--clip": cfg.clip = try Float(next()) ?? cfg.clip
			case "--vcoef": cfg.vcoef = try Float(next()) ?? cfg.vcoef
			case "--kl": cfg.kl = try Float(next()) ?? cfg.kl
			case "--ent": cfg.ent = try Float(next()) ?? cfg.ent
			case "--vwarm": vwarm = try Int(next()) ?? vwarm
			case "--lam": lam = try Float(next()) ?? lam
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		guard let weightsPath else {
			throw TrainError.usage("ppo needs --weights <pgw> (a BC checkpoint)")
		}
		guard (0 ... 3).contains(curriculum) else {
			throw TrainError.usage("--curriculum must be between 0 and 3")
		}
		let weights = try LSTMWeights.load(weightsPath)
		let ref = try refPath.map { try LSTMWeights.load($0) } ?? weights

		let outDir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

		let graph = try PPOGraph(weights: weights, ref: ref, b: b, t: t, cfg: cfg)
		var battleIndex = seed
		// Adam bias correction is per update path: warmup windows never touch
		// the actor/trunk moments, so the live path must start its correction
		// at t = 1 — under one shared counter the first policy updates land on
		// zero moments with a matured correction factor, ~3–5× too large. The
		// value head's moments are older than policyStep claims; the stale-low
		// correction only damps its first live steps, which is benign.
		var valueStep = 0
		var policyStep = 0
		var schedule = RLTrainer.Curriculum(level: curriculum, anneal: anneal)
		var csv = "iter,wins,losses,draws,meanR,ev,madv,settle,units,prestige,days,samples,loss,surr,vloss,kl,ent,clipfrac,akl,windows,level,arenaWin\n"
		let clock = ContinuousClock()
		let start = clock.now

		for iter in 1 ... iters {
			// On-policy batch with the graph's current weights.
			let current = graph.checkpoint()
			let batch = RLTrainer.collect(
				weights: current, count: episodes, startIndex: battleIndex,
				temp: cfg.temp, difficulty: schedule.difficulty, suite: suite
			)
			battleIndex += episodes
			let episodeList = batch.map { ($0.replay, $0.seat, Float(1)) }

			// Read pass: per-sample old log-prob and value under the collection
			// weights, cached per window ordinal.
			var cache = [PPOGraph.Cached]()
			do {
				let batcher = Batcher(episodes: episodeList, b: b, t: t)
				while true {
					let w = batcher.window()
					guard w.samples > 0 else { break }
					let r = graph.read(w)
					batcher.carry(h: r.h, c: r.c)
					cache.append(PPOGraph.Cached(
						oldLogp: r.logp, value: r.value, epi: w.epi,
						valid: w.kindW, samples: w.samples
					))
				}
			}

			// GAE over each episode's value sequence (γ = 1; terminal-only
			// reward). λ = 1 telescopes to exactly A_t = R − V(s_t); the value
			// target is the λ-return A + V (= R at λ = 1). Sample order within
			// an episode is windows-outer/steps-inner in its lane — the same
			// order the streams produced them.
			let (adv, ret, madv, ev) = advantages(cache: cache, batch: batch, b: b, t: t, lam: lam)

			// Value warmup: the head starts at random init, and letting its
			// loss backprop into the shared trunk would shift the policy
			// heads' inputs under them — so the first iterations update the
			// value head alone, and the curriculum stays frozen (the BC prior
			// already wins ~40% at level 3; winEMA would fire the descent
			// while the policy isn't training).
			let warming = iter <= vwarm
			var sums = PPOGraph.Metrics()
			var windows = 0
			for _ in 0 ..< cfg.epochs {
				let batcher = Batcher(episodes: episodeList, b: b, t: t)
				var k = 0
				while true {
					let w = batcher.window()
					guard w.samples > 0 else { break }
					guard k < cache.count, w.epi == cache[k].epi, w.samples == cache[k].samples else {
						throw TrainError.failed("PPO window \(k) does not match the read pass")
					}
					if warming { valueStep += 1 } else { policyStep += 1 }
					// The loss is mean-per-valid-sample and Adam normalizes
					// gradient scale away, so every window would otherwise step
					// equally hard — scaling lr by the fill keeps a near-empty
					// tail window (the longest episodes' remainders) from
					// voting like a full one.
					let fill = Float(w.samples) / Float(b * t)
					let m = graph.step(
						w, oldLogp: cache[k].oldLogp, adv: adv[k], ret: ret[k],
						lr: Net.correctedLR(lr, step: warming ? valueStep : policyStep) * fill,
						polCoef: warming ? 0 : 1, valueOnly: warming
					)
					batcher.carry(h: m.h, c: m.c, hr: m.hr, cr: m.cr)
					sums.add(m)
					windows += 1
					k += 1
				}
				guard k == cache.count else {
					throw TrainError.failed("PPO epoch produced \(k) windows, read pass had \(cache.count)")
				}
			}
			sums.scale(1 / Float(max(windows, 1)))

			let stats = RLTrainer.BatchStats(batch)
			print("iter \(iter)\(warming ? " (vwarm)" : "")  \(stats.wins)W \(stats.losses)L \(stats.draws)D  R \(f(stats.meanR))  ev \(f(ev))  |A| \(f(madv))  surr \(f(sums.surr))  v \(f(sums.vloss))  kl \(f(sums.kl))  clip \(f(sums.clipFrac))  settle \(f(stats.settle))  units \(f(stats.units))  days \(stats.days)  samples \(stats.samples)\(schedule.difficulty > 0 ? "  d \(f(schedule.difficulty))" : "")")

			// Self-paced curriculum, unchanged v3.1 semantics (see RLTrainer);
			// frozen while the value head warms up.
			if !warming, let move = schedule.update(winRate: Float(stats.wins) / Float(batch.count)) {
				print("  \(move)")
			}

			var arena = ""
			if iter % ckpt == 0 || iter == iters {
				arena = try RLTrainer.dumpCheckpoint(
					graph.checkpoint(), iter: iter, outDir: outDir,
					evalN: evalN, suite: suite, batch: batch
				)
			}
			csv += "\(iter),\(stats.wins),\(stats.losses),\(stats.draws),\(stats.meanR),\(ev),\(madv),\(stats.settle),\(stats.units),\(stats.prestige),\(stats.days),\(stats.samples),\(sums.loss),\(sums.surr),\(sums.vloss),\(sums.kl),\(sums.ent),\(sums.clipFrac),\(sums.akl),\(windows),\(schedule.difficulty),\(arena)\n"
			try csv.write(to: outDir.appendingPathComponent("ppo-log.csv"), atomically: true, encoding: .utf8)
		}

		try graph.checkpoint().data().write(to: outDir.appendingPathComponent("policy.pgw"))
		let d = start.duration(to: clock.now).components
		print("── ppo ──")
		print("  iters:    \(iters) (\(d.seconds)s, \(battleIndex - seed) episodes)")
		print("  suite:    \(suite.rawValue)")
		print("  out:      \(outDir.path)/policy.pgw")
	}

	/// GAE per episode from the cached read pass, then batch-wide advantage
	/// normalization (mean 0 / std 1, clamped ±5). Returns per-window
	/// advantage and value-target arrays plus the raw mean |A| and the value
	/// head's explained variance against the Monte-Carlo return — the health
	/// metric that says whether the baseline is doing anything yet.
	static func advantages(
		cache: [PPOGraph.Cached],
		batch: [RLTrainer.Episode],
		b: Int, t: Int,
		lam: Float
	) -> (adv: [[Float]], ret: [[Float]], madv: Float, ev: Float) {
		var seq = [[(k: Int, i: Int)]](repeating: [], count: batch.count)
		for (k, c) in cache.enumerated() {
			for lane in 0 ..< b {
				for step in 0 ..< t {
					let i = step * b + lane
					guard c.valid[i] > 0, c.epi[i] >= 0 else { continue }
					seq[Int(c.epi[i])].append((k, i))
				}
			}
		}

		var adv = cache.map { [Float](repeating: 0, count: $0.epi.count) }
		var ret = cache.map { [Float](repeating: 0, count: $0.epi.count) }
		var sum: Float = 0, sqsum: Float = 0, absSum: Float = 0, count: Float = 0
		var mcVarSum: Float = 0, mcSum: Float = 0, resSum: Float = 0
		for (e, s) in seq.enumerated() {
			guard !s.isEmpty else { continue }
			let R = batch[e].reward
			var a: Float = 0
			for j in s.indices.reversed() {
				let v = cache[s[j].k].value[s[j].i]
				let next = j == s.count - 1
					? (r: R, v: Float(0))
					: (r: 0, v: cache[s[j + 1].k].value[s[j + 1].i])
				a = next.r + next.v - v + lam * a
				adv[s[j].k][s[j].i] = a
				ret[s[j].k][s[j].i] = a + v
				sum += a
				sqsum += a * a
				absSum += abs(a)
				count += 1
				mcSum += R
				mcVarSum += R * R
				resSum += (R - v) * (R - v)
			}
		}
		guard count > 0 else { return (adv, ret, 0, 0) }

		let mean = sum / count
		let std = max((sqsum / count - mean * mean).squareRoot(), 1e-3)
		let madv = absSum / count
		for k in adv.indices {
			for i in adv[k].indices where cache[k].valid[i] > 0 {
				adv[k][i] = max(-5, min(5, (adv[k][i] - mean) / std))
			}
		}
		let mcVar = mcVarSum / count - (mcSum / count) * (mcSum / count)
		let ev = mcVar > 1e-8 ? 1 - (resSum / count) / mcVar : 0
		return (adv, ret, madv, ev)
	}
}

/// The PPO training graph: the same `Net` unroll as `BCGraph`, but the loss
/// is the clipped surrogate over the joint (per-head, applicability-weighted)
/// log-prob of the taken actions, plus the value MSE and — when `--kl` > 0 —
/// a full-distribution KL to a frozen constant copy of the network with its
/// own recurrent state. Two update paths share one set of Adam moments: the
/// full loss over every variable, and a value-head-only path for warmup.
final class PPOGraph {
	let graph = MPSGraph()
	let device: MPSGraphDevice
	let queue: MTLCommandQueue
	let b: Int
	let t: Int
	let cfg: PPOTrainer.Config
	var n: Int { b * t }

	private let planes, globals, h0, c0, lrIn, polCoefIn: MPSGraphTensor
	private let kindLabel, actorLabel, targetLabel, slotLabel: MPSGraphTensor
	private let kindW, actorW, targetW, slotW: MPSGraphTensor
	private let kindMask, actorMask, targetMask, slotMask: MPSGraphTensor
	private let advIn, oldLogpIn, retIn: MPSGraphTensor
	private var h0r, c0r: MPSGraphTensor?
	private var hrT, crT: MPSGraphTensor?
	private let loss, surr, vLoss, klMean, entMean, clipFrac, approxKL: MPSGraphTensor
	private let logpNew, value, hT, cT: MPSGraphTensor
	private let updatesAll, updatesValue: [MPSGraphOperation]
	private let vars: [String: MPSGraphTensor]

	struct Cached {
		var oldLogp: [Float]
		var value: [Float]
		var epi: [Int32]
		var valid: [Float]
		var samples: Int
	}

	struct ReadOut {
		var logp: [Float] = []
		var value: [Float] = []
		var h: [Float] = [], c: [Float] = []
	}

	struct Metrics {
		var loss: Float = 0
		var surr: Float = 0
		var vloss: Float = 0
		var kl: Float = 0
		var ent: Float = 0
		var clipFrac: Float = 0
		var akl: Float = 0
		var h: [Float] = [], c: [Float] = []
		var hr: [Float]?, cr: [Float]?

		mutating func add(_ m: Metrics) {
			loss += m.loss
			surr += m.surr
			vloss += m.vloss
			kl += m.kl
			ent += m.ent
			clipFrac += m.clipFrac
			akl += m.akl
		}

		mutating func scale(_ w: Float) {
			loss *= w
			surr *= w
			vloss *= w
			kl *= w
			ent *= w
			clipFrac *= w
			akl *= w
		}
	}

	init(weights: LSTMWeights, ref: LSTMWeights, b: Int, t: Int, cfg: PPOTrainer.Config) throws {
		guard let mtl = MTLCreateSystemDefaultDevice(), let q = mtl.makeCommandQueue() else {
			throw TrainError.failed("no Metal device")
		}
		device = MPSGraphDevice(mtlDevice: mtl)
		queue = q
		self.b = b
		self.t = t
		self.cfg = cfg
		let n = b * t

		let g = graph
		let H = LSTMWeights.hidden
		let side = NSNumber(value: SimObservation.side)
		let nn = NSNumber(value: n)
		func ph(_ shape: [NSNumber], _ type: MPSDataType, _ name: String) -> MPSGraphTensor {
			g.placeholder(shape: shape, dataType: type, name: name)
		}
		planes = ph([nn, side, side, NSNumber(value: SimObservation.planeCount)], .float32, "planes")
		globals = ph([nn, NSNumber(value: SimObservation.globalCount)], .float32, "globals")
		h0 = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "h0")
		c0 = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "c0")
		let lrT = ph([1], .float32, "lr")
		lrIn = lrT
		polCoefIn = ph([1], .float32, "polCoef")
		kindLabel = ph([nn], .int32, "kindLabel")
		actorLabel = ph([nn], .int32, "actorLabel")
		targetLabel = ph([nn], .int32, "targetLabel")
		slotLabel = ph([nn], .int32, "slotLabel")
		kindW = ph([nn, 1], .float32, "kindW")
		actorW = ph([nn, 1], .float32, "actorW")
		targetW = ph([nn, 1], .float32, "targetW")
		slotW = ph([nn, 1], .float32, "slotW")
		kindMask = ph([nn, NSNumber(value: ActionSpace.kinds)], .float32, "kindMask")
		actorMask = ph([nn, NSNumber(value: ActionSpace.tiles)], .float32, "actorMask")
		targetMask = ph([nn, NSNumber(value: ActionSpace.tiles)], .float32, "targetMask")
		slotMask = ph([nn, NSNumber(value: ActionSpace.slots)], .float32, "slotMask")
		advIn = ph([nn, 1], .float32, "adv")
		oldLogpIn = ph([nn, 1], .float32, "oldLogp")
		retIn = ph([nn, 1], .float32, "ret")

		let one = g.constant(1, dataType: .float32)
		let eps = g.constant(1e-10, dataType: .float32)

		// Masked logits, with the sampling temperature folded in so the graph
		// scores exactly the distribution collection sampled from.
		func masked(_ logits: MPSGraphTensor, _ mask: MPSGraphTensor) -> MPSGraphTensor {
			var scaled = logits
			if cfg.temp != 1 {
				scaled = g.multiplication(scaled, g.constant(1 / Double(cfg.temp), dataType: .float32), name: nil)
			}
			return g.addition(
				scaled,
				g.multiplication(
					g.subtraction(mask, one, name: nil),
					g.constant(1e9, dataType: .float32), name: nil
				), name: nil
			)
		}
		// log π(label) per sample: −CE against the one-hot label (labels are
		// always mask-legal, so the −1e9 shift cancels out of the result).
		func labelLogp(_ maskedLogits: MPSGraphTensor, _ label: MPSGraphTensor, _ k: Int) -> MPSGraphTensor {
			let labels = g.oneHot(withIndicesTensor: label, depth: k, axis: 1, dataType: .float32, name: nil)
			let ce = g.reshape(
				g.softMaxCrossEntropy(maskedLogits, labels: labels, axis: 1, reuctionType: .none, name: nil),
				shape: [nn, 1], name: nil
			)
			return g.negative(with: ce, name: nil)
		}
		// Σ p·log(p+ε): illegal entries have p = 0 exactly (softmax of −1e9),
		// and the +ε keeps their log finite, so they contribute nothing.
		func plogp(_ p: MPSGraphTensor, _ logq: MPSGraphTensor) -> MPSGraphTensor {
			g.reductionSum(with: g.multiplication(p, logq, name: nil), axes: [1], name: nil)
		}
		func logp(_ p: MPSGraphTensor) -> MPSGraphTensor {
			g.logarithm(with: g.addition(p, eps, name: nil), name: nil)
		}

		let v = Net.variables(g, weights)
		vars = v
		let (trunk, x) = Net.encode(g, v, planes: planes, globals: globals, n: n)

		// Unroll: x [n, H] is t-major, so slice t rows of [b, H] at a time.
		func unroll(
			_ v: [String: MPSGraphTensor], _ x: MPSGraphTensor,
			_ h0: MPSGraphTensor, _ c0: MPSGraphTensor
		) -> (all: MPSGraphTensor, h: MPSGraphTensor, c: MPSGraphTensor) {
			let x3 = g.reshape(x, shape: [NSNumber(value: t), NSNumber(value: b), NSNumber(value: H)], name: nil)
			var h = h0
			var c = c0
			var hs = [MPSGraphTensor]()
			for step in 0 ..< t {
				let xt = g.reshape(
					g.sliceTensor(x3, dimension: 0, start: step, length: 1, name: nil),
					shape: [NSNumber(value: b), NSNumber(value: H)], name: nil
				)
				(h, c) = Net.cell(g, v, x: xt, h: h, c: c)
				hs.append(h)
			}
			return (g.concatTensors(hs, dimension: 0, name: nil), h, c)
		}
		let un = unroll(v, x, h0, c0)
		hT = un.h
		cT = un.c

		let kindLogits = masked(Net.kindHead(g, v, h: un.all), kindMask)
		let actorLogits = masked(Net.actorHead(g, v, trunk: trunk, h: un.all, n: n), actorMask)
		let cond = Net.condHeads(g, v, trunk: trunk, h: un.all, actor: actorLabel, n: n)
		let targetLogits = masked(cond.target, targetMask)
		let slotLogits = masked(cond.slot, slotMask)
		value = Net.valueHead(g, v, h: un.all)

		// Joint log-prob of the taken action = Σ heads, weighted by
		// applicability (the W arrays are 0/1 in episode mode).
		let heads: [(logits: MPSGraphTensor, label: MPSGraphTensor, w: MPSGraphTensor, k: Int)] = [
			(kindLogits, kindLabel, kindW, ActionSpace.kinds),
			(actorLogits, actorLabel, actorW, ActionSpace.tiles),
			(targetLogits, targetLabel, targetW, ActionSpace.tiles),
			(slotLogits, slotLabel, slotW, ActionSpace.slots),
		]
		var jointLogp: MPSGraphTensor?
		for head in heads {
			let term = g.multiplication(head.w, labelLogp(head.logits, head.label, head.k), name: nil)
			jointLogp = jointLogp.map { g.addition($0, term, name: nil) } ?? term
		}
		logpNew = jointLogp!

		let valid = kindW		// 1 on every real sample, 0 on padding
		let validSum = g.maximum(g.reductionSum(with: valid, axes: nil, name: nil), one, name: nil)
		func meanValid(_ x: MPSGraphTensor) -> MPSGraphTensor {
			g.division(g.reductionSum(with: g.multiplication(valid, x, name: nil), axes: nil, name: nil), validSum, name: nil)
		}

		// PPO-clip surrogate. Clamps are min/max compositions throughout —
		// the dedicated clamp op is outside the verified-gradient set.
		let logr = g.subtraction(logpNew, oldLogpIn, name: nil)
		let logrSafe = g.minimum(
			g.maximum(logr, g.constant(-20, dataType: .float32), name: nil),
			g.constant(20, dataType: .float32), name: nil
		)
		let ratio = g.exponent(with: logrSafe, name: nil)
		let clipped = g.minimum(
			g.maximum(ratio, g.constant(1 - Double(cfg.clip), dataType: .float32), name: nil),
			g.constant(1 + Double(cfg.clip), dataType: .float32), name: nil
		)
		surr = g.negative(with: meanValid(g.minimum(
			g.multiplication(ratio, advIn, name: nil),
			g.multiplication(clipped, advIn, name: nil), name: nil
		)), name: nil)
		clipFrac = meanValid(g.cast(
			g.greaterThan(
				g.absolute(with: g.subtraction(ratio, one, name: nil), name: nil),
				g.constant(Double(cfg.clip), dataType: .float32), name: nil
			), to: .float32, name: nil
		))
		// k3 estimate of KL(π_old ‖ π_new) — the drift-per-iteration gauge.
		approxKL = meanValid(g.subtraction(g.subtraction(ratio, one, name: nil), logrSafe, name: nil))

		let vErr = g.subtraction(value, retIn, name: nil)
		vLoss = meanValid(g.square(with: vErr, name: nil))

		// Entropy always (logged; in the loss only when --ent > 0), the KL
		// anchor branch only when --kl > 0: a second full forward pass of the
		// network with the reference weights as constants and its own
		// recurrent state, teacher-forced on the same actor labels.
		var entJoint: MPSGraphTensor?
		var klJoint: MPSGraphTensor?
		var refMasked = [MPSGraphTensor]()
		if cfg.kl > 0 {
			let rv = Net.constants(g, ref)
			let h0rT = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "h0r")
			let c0rT = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "c0r")
			h0r = h0rT
			c0r = c0rT
			let (trunkR, xR) = Net.encode(g, rv, planes: planes, globals: globals, n: n)
			let unR = unroll(rv, xR, h0rT, c0rT)
			hrT = unR.h
			crT = unR.c
			let condR = Net.condHeads(g, rv, trunk: trunkR, h: unR.all, actor: actorLabel, n: n)
			refMasked = [
				masked(Net.kindHead(g, rv, h: unR.all), kindMask),
				masked(Net.actorHead(g, rv, trunk: trunkR, h: unR.all, n: n), actorMask),
				masked(condR.target, targetMask),
				masked(condR.slot, slotMask),
			]
		}
		for (j, head) in heads.enumerated() {
			let p = g.softMax(with: head.logits, axis: 1, name: nil)
			let lp = logp(p)
			let ent = g.negative(with: plogp(p, lp), name: nil)
			let entTerm = g.multiplication(head.w, ent, name: nil)
			entJoint = entJoint.map { g.addition($0, entTerm, name: nil) } ?? entTerm
			if cfg.kl > 0 {
				let lpRef = logp(g.softMax(with: refMasked[j], axis: 1, name: nil))
				let kl = g.subtraction(plogp(p, lp), plogp(p, lpRef), name: nil)
				let klTerm = g.multiplication(head.w, kl, name: nil)
				klJoint = klJoint.map { g.addition($0, klTerm, name: nil) } ?? klTerm
			}
		}
		entMean = meanValid(entJoint!)
		klMean = cfg.kl > 0 ? meanValid(klJoint!) : g.constant(0, dataType: .float32)

		var total = g.addition(
			g.multiplication(polCoefIn, surr, name: nil),
			g.multiplication(g.constant(Double(cfg.vcoef), dataType: .float32), vLoss, name: nil),
			name: nil
		)
		if cfg.kl > 0 {
			total = g.addition(total, g.multiplication(g.constant(Double(cfg.kl), dataType: .float32), klMean, name: nil), name: nil)
		}
		if cfg.ent > 0 {
			total = g.subtraction(total, g.multiplication(g.constant(Double(cfg.ent), dataType: .float32), entMean, name: nil), name: nil)
		}
		loss = total

		// Adam with global-norm clip at 1.0, as in BC — twice: the full loss
		// over every variable (the value head is trainable here, unlike BC),
		// and the value MSE over the value head alone for warmup. Both paths
		// share moment state per variable.
		var moments = [String: (m: MPSGraphTensor, v: MPSGraphTensor)]()
		for (name, variable) in v {
			let shape = variable.shape!
			let zeros = floatData([Float](repeating: 0, count: shape.reduce(1) { $0 * $1.intValue }))
			moments[name] = (
				g.variable(with: zeros, shape: shape, dataType: .float32, name: "adam.m.\(name)"),
				g.variable(with: zeros, shape: shape, dataType: .float32, name: "adam.v.\(name)")
			)
		}
		func adamOps(_ objective: MPSGraphTensor, _ trainable: [String: MPSGraphTensor]) -> [MPSGraphOperation] {
			let grads = g.gradients(of: objective, with: Array(trainable.values), name: nil)
			var sumSq = g.constant(0, dataType: .float32)
			for grad in grads.values {
				sumSq = g.addition(sumSq, g.reductionSum(with: g.square(with: grad, name: nil), axes: nil, name: nil), name: nil)
			}
			let norm = g.squareRoot(with: sumSq, name: nil)
			let scale = g.minimum(
				g.constant(1, dataType: .float32),
				g.division(g.constant(1, dataType: .float32), g.addition(norm, g.constant(1e-12, dataType: .float32), name: nil), name: nil),
				name: nil
			)
			let beta1 = g.constant(0.9, dataType: .float32)
			let beta2 = g.constant(0.999, dataType: .float32)
			let epsilon = g.constant(1e-8, dataType: .float32)
			var ops = [MPSGraphOperation]()
			for (name, variable) in trainable {
				guard let grad = grads[variable], let mv = moments[name] else { continue }
				let adam = g.adam(
					currentLearningRate: lrT, beta1: beta1, beta2: beta2, epsilon: epsilon,
					values: variable, momentum: mv.m, velocity: mv.v, maximumVelocity: nil,
					gradient: g.multiplication(grad, scale, name: nil), name: nil
				)
				ops.append(g.assign(variable, tensor: adam[0], name: nil))
				ops.append(g.assign(mv.m, tensor: adam[1], name: nil))
				ops.append(g.assign(mv.v, tensor: adam[2], name: nil))
			}
			return ops
		}
		updatesAll = adamOps(loss, v)
		updatesValue = adamOps(vLoss, v.filter { $0.key.hasPrefix("value.") })
	}

	// MARK: - Runs

	private func feeds(_ w: Batcher.Window) -> [MPSGraphTensor: MPSGraphTensorData] {
		let side = NSNumber(value: SimObservation.side)
		let nn = NSNumber(value: n)
		let bh: [NSNumber] = [NSNumber(value: b), NSNumber(value: LSTMWeights.hidden)]
		var feeds: [MPSGraphTensor: MPSGraphTensorData] = [
			planes: tensorData(device, w.planes, [nn, side, side, NSNumber(value: SimObservation.planeCount)]),
			globals: tensorData(device, w.globals, [nn, NSNumber(value: SimObservation.globalCount)]),
			h0: tensorData(device, w.h0, bh),
			c0: tensorData(device, w.c0, bh),
			kindLabel: tensorData(device, w.kind, [nn]),
			actorLabel: tensorData(device, w.actor, [nn]),
			targetLabel: tensorData(device, w.target, [nn]),
			slotLabel: tensorData(device, w.slot, [nn]),
			kindW: tensorData(device, w.kindW, [nn, 1]),
			actorW: tensorData(device, w.actorW, [nn, 1]),
			targetW: tensorData(device, w.targetW, [nn, 1]),
			slotW: tensorData(device, w.slotW, [nn, 1]),
			kindMask: tensorData(device, w.kindMask, [nn, NSNumber(value: ActionSpace.kinds)]),
			actorMask: tensorData(device, w.actorMask, [nn, NSNumber(value: ActionSpace.tiles)]),
			targetMask: tensorData(device, w.targetMask, [nn, NSNumber(value: ActionSpace.tiles)]),
			slotMask: tensorData(device, w.slotMask, [nn, NSNumber(value: ActionSpace.slots)]),
		]
		if let h0r, let c0r {
			feeds[h0r] = tensorData(device, w.h0r, bh)
			feeds[c0r] = tensorData(device, w.c0r, bh)
		}
		return feeds
	}

	/// The read pass: per-sample joint log-prob and value under the current
	/// (= collection) weights, plus the h/c carry. No update, no loss feeds.
	func read(_ w: Batcher.Window) -> ReadOut {
		autoreleasepool {
			let out = graph.run(
				with: queue, feeds: feeds(w),
				targetTensors: [logpNew, value, hT, cT], targetOperations: nil
			)
			var r = ReadOut()
			r.logp = readFloats(out[logpNew]!, n)
			r.value = readFloats(out[value]!, n)
			r.h = readFloats(out[hT]!, b * LSTMWeights.hidden)
			r.c = readFloats(out[cT]!, b * LSTMWeights.hidden)
			return r
		}
	}

	/// One optimization window; `valueOnly` runs the warmup path (value-head
	/// Adam only). The autoreleasepool is load-bearing: the feeds are
	/// autoreleased ObjC objects and a CLI has no runloop to drain them.
	func step(
		_ w: Batcher.Window, oldLogp: [Float], adv: [Float], ret: [Float],
		lr: Float, polCoef: Float, valueOnly: Bool
	) -> Metrics {
		autoreleasepool {
			let nn = NSNumber(value: n)
			var f = feeds(w)
			f[lrIn] = tensorData(device, [lr], [1])
			f[polCoefIn] = tensorData(device, [polCoef], [1])
			f[oldLogpIn] = tensorData(device, oldLogp, [nn, 1])
			f[advIn] = tensorData(device, adv, [nn, 1])
			f[retIn] = tensorData(device, ret, [nn, 1])

			var targets = [loss, surr, vLoss, klMean, entMean, clipFrac, approxKL, hT, cT]
			if let hrT, let crT { targets += [hrT, crT] }
			let out = graph.run(
				with: queue, feeds: f,
				targetTensors: targets, targetOperations: valueOnly ? updatesValue : updatesAll
			)

			var m = Metrics()
			m.loss = readFloats(out[loss]!, 1)[0]
			m.surr = readFloats(out[surr]!, 1)[0]
			m.vloss = readFloats(out[vLoss]!, 1)[0]
			m.kl = readFloats(out[klMean]!, 1)[0]
			m.ent = readFloats(out[entMean]!, 1)[0]
			m.clipFrac = readFloats(out[clipFrac]!, 1)[0]
			m.akl = readFloats(out[approxKL]!, 1)[0]
			m.h = readFloats(out[hT]!, b * LSTMWeights.hidden)
			m.c = readFloats(out[cT]!, b * LSTMWeights.hidden)
			if let hrT, let crT {
				m.hr = readFloats(out[hrT]!, b * LSTMWeights.hidden)
				m.cr = readFloats(out[crT]!, b * LSTMWeights.hidden)
			}
			return m
		}
	}

	/// Current variable values as a PGW1-writable weight set.
	func checkpoint() -> LSTMWeights {
		autoreleasepool {
			let out = graph.run(with: queue, feeds: [:], targetTensors: Array(vars.values), targetOperations: nil)
			var values = [String: [Float]]()
			for (name, shape) in LSTMWeights.spec {
				values[name] = readFloats(out[vars[name]!]!, shape.reduce(1, *))
			}
			return LSTMWeights(values: values)
		}
	}
}
