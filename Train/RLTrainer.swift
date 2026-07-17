import Foundation
import COR

/// `Train rl` — REINFORCE fine-tune of a BC checkpoint against the frozen
/// heuristic. Each iteration plays a batch of episodes with masked-softmax
/// *sampling* (own `D20` instance — the sim's is never touched), scores them
/// with a terminal reward, and replays them through the BC graph as
/// advantage-weighted cross-entropy — with `Σ|w|` normalization that is
/// exactly the policy gradient. The baseline is the leave-one-out mean of the
/// episode's difficulty-level group (within-batch advantages always straddle
/// zero — an EMA baseline went stale after a policy shift and un-learned the
/// BC prior, see run 4; a shared mean over a mixed-difficulty batch graded
/// episodes by their matchup, not their play, see run 8); advantages
/// are normalized to mean |A| = 1 per batch and clamped to ±3 (the graph
/// divides by Σ|w| per window, so this keeps every window's scale honest).
///
/// Reward: dense, symmetric progress terms — win/loss alone starves
/// REINFORCE when the sampled win rate is ~0 (run-2 lesson: the policy
/// drifted to "don't lose" stalling). Each term is ~[−1, 1]:
///   settlements  Δ(own − enemy settlement count) / total on map — capture
///                is good, being captured is bad; control IS the win
///                condition, so this is the win/loss signal made dense
///   units        enemy value killed − own value lost, each as a fraction
///                of that side's starting value (hp-weighted unit cost,
///                accumulated per step so purchases don't pollute it)
///   kills        enemy units destroyed − own units lost, each as a fraction
///                of that side's starting unit count — the value term pays
///                for damage; this pays extra for finishing units off
///   prestige     (mine − theirs) / (mine + theirs) at episode end
///   outcome      ±wOutcome on a decided battle; timeouts score 0 here and
///                are judged by the dense terms instead
/// Argmax arena checkpoints (`Eval.play`, battle indices 0…) track real
/// strength on the same configs `Train eval` reports.
enum RLTrainer {

	static let wOutcome: Float = 0.5
	static let wSettlements: Float = 1.0
	static let wUnits: Float = 0.25
	static let wKills: Float = 0.5
	static let wPrestige: Float = 0.1

	struct Episode {
		var replay: Replay
		var seat: Int
		var level = 0
		var reward: Float = 0
		var outcome = "D"
		var samples = 0
		var settleTerm: Float = 0
		var unitTerm: Float = 0
		var killTerm: Float = 0
		var prestigeTerm: Float = 0
	}

	/// Per-iteration aggregates over a collected batch — the numbers both the
	/// RL and PPO loops print and log.
	struct BatchStats {
		var wins = 0
		var losses = 0
		var draws = 0
		var days = 0
		var samples = 0
		var meanR: Float = 0
		var settle: Float = 0
		var units: Float = 0
		var kills: Float = 0
		var prestige: Float = 0

		init(_ batch: [Episode]) {
			let n = Float(batch.count)
			wins = batch.count(where: { $0.outcome == "W" })
			losses = batch.count(where: { $0.outcome == "L" })
			draws = batch.count - wins - losses
			days = batch.reduce(0) { $0 + Int($1.replay.days) } / batch.count
			samples = batch.reduce(0) { $0 + $1.samples }
			meanR = batch.reduce(0) { $0 + $1.reward } / n
			settle = batch.reduce(0) { $0 + $1.settleTerm } / n
			units = batch.reduce(0) { $0 + $1.unitTerm } / n
			kills = batch.reduce(0) { $0 + $1.killTerm } / n
			prestige = batch.reduce(0) { $0 + $1.prestigeTerm } / n
		}
	}

	/// Self-paced curriculum, both directions: winning comfortably nudges
	/// difficulty down a quarter-step (soft EMA decay keeps momentum across
	/// smooth terrain); a *starving* stretch nudges it back up. Starvation is
	/// winEMA under a floor, not a strict zero-win streak — run 8 parked 20
	/// iterations at W1–2/16, too many wins to ever hit six consecutive
	/// zeros, hopelessly short of the descent threshold. On ascent winEMA
	/// restarts at 0.2: above the floor so the easier mix gets a fair
	/// evaluation window, below the descent threshold so it must earn the
	/// way back down. Shared by the RL and PPO loops — one definition of the
	/// tuned v3.1 semantics.
	struct Curriculum {
		var difficulty: Float
		let ceiling: Float
		let anneal: Float
		var winEMA: Float = 0
		var starved = 0

		init(level: Float, anneal: Float) {
			difficulty = level
			ceiling = level
			self.anneal = anneal
		}

		/// One post-iteration update. Returns a log line when difficulty moved.
		mutating func update(winRate: Float) -> String? {
			winEMA = 0.8 * winEMA + 0.2 * winRate
			if difficulty > 0, winEMA > anneal {
				difficulty = max(0, difficulty - 0.25)
				winEMA *= 0.5
				starved = 0
				return "curriculum → difficulty \(f(difficulty))"
			} else if difficulty < ceiling, winEMA < 0.10 {
				starved += 1
				if starved >= 6 {
					difficulty = min(ceiling, difficulty + 0.25)
					starved = 0
					winEMA = 0.2
					return "curriculum → difficulty \(f(difficulty)) (win starvation)"
				}
			} else {
				starved = 0
			}
			return nil
		}
	}

	static func run(_ args: [String]) throws {
		var weightsPath: String?
		var out = "tmp/runs/rl"
		var iters = 100
		var episodes = 16
		var b = 16
		var t = 16
		var lr: Float = 2e-5
		var temp: Float = 1
		var seed = 1000
		var ckpt = 10
		var evalN = 8
		var curriculum: Float = 0
		var anneal: Float = 0.35
		var suite: RolloutSuite = .mixed

		try Args(args).parse { flag, next in
			switch flag {
			case "--weights": weightsPath = try next()
			case "--out": out = try next()
			case "--iters": iters = try Int(next()) ?? iters
			case "--episodes": episodes = try Int(next()) ?? episodes
			case "--b": b = try Int(next()) ?? b
			case "--t": t = try Int(next()) ?? t
			case "--lr": lr = try Float(next()) ?? lr
			case "--temp": temp = try Float(next()) ?? temp
			case "--seed": seed = try Int(next()) ?? seed
			case "--ckpt": ckpt = try Int(next()) ?? ckpt
			case "--evaln": evalN = try Int(next()) ?? evalN
			case "--curriculum": curriculum = try Float(next()) ?? curriculum
			case "--anneal": anneal = try Float(next()) ?? anneal
			case "--suite": suite = try .parse(next())
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		guard let weightsPath else {
			throw TrainError.usage("rl needs --weights <pgw> (a BC checkpoint)")
		}
		guard (0 ... 3).contains(curriculum) else {
			throw TrainError.usage("--curriculum must be between 0 and 3")
		}
		let weights = try LSTMWeights.load(weightsPath)

		let outDir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

		let graph = try BCGraph(weights: weights, b: b, t: t)
		var battleIndex = seed
		var globalStep = 0
		var schedule = Curriculum(level: curriculum, anneal: anneal)
		var csv = "iter,wins,losses,draws,meanR,madv,settle,units,kills,prestige,days,samples,loss,windows,level,arenaWin\n"
		let clock = ContinuousClock()
		let start = clock.now

		for iter in 1 ... iters {
			// On-policy batch with the graph's current weights.
			let current = graph.checkpoint()
			let batch = collect(
				weights: current, count: episodes, startIndex: battleIndex,
				temp: temp, difficulty: schedule.difficulty, suite: suite
			)
			battleIndex += episodes

			// Leave-one-out baseline, stratified by drawn difficulty level:
			// within-batch advantages always straddle zero, so a policy shift
			// can never turn a whole update into a wholesale push-down (run-4
			// lesson: the EMA baseline went stale after the first big shift,
			// every advantage went ≈ −1.3 for eight iterations straight, and
			// the BC prior was unlearned). Stratification because a mixed
			// batch under one shared mean confounds "which level did you
			// draw" with "how well did you act" — harder-level episodes sit
			// systematically below the mean and every update leaks "push down
			// whatever the policy does at the harder level" (run-8 lesson:
			// parked at d=2.5 the wins decayed 5→1 of 16 over 20 iterations).
			// A singleton group has no baseline and contributes no gradient.
			// The clamp bounds any single episode's pull after normalization.
			let n = Float(batch.count)
			var advantages = [Float](repeating: 0, count: batch.count)
			for level in Set(batch.map(\.level)) {
				let group = batch.indices.filter { batch[$0].level == level }
				guard group.count > 1 else { continue }
				let g = Float(group.count)
				let mean = group.reduce(0) { $0 + batch[$1].reward } / g
				for j in group {
					advantages[j] = (batch[j].reward - mean) * g / (g - 1)
				}
			}
			let meanAbs = max(advantages.reduce(0) { $0 + abs($1) } / n, 0.1)
			advantages = advantages.map { a in max(-3, min(3, a / meanAbs)) }

			// Length-normalized: an episode's gradient mass is ∝ its sample
			// count, and losing/drawing episodes run to the day cap with
			// thousands of actions while wins end early with few — unscaled,
			// the update is dominated by "push down whatever long episodes
			// do", which is acting at all (run-4b lesson: one update halved
			// samples/episode and the policy just ended turns). Scaling by
			// meanSamples/samples makes each episode vote once.
			let meanSamples = batch.reduce(0) { $0 + Float($1.samples) } / n
			let batcher = Batcher(
				episodes: batch.indices.map { j in
					(batch[j].replay, batch[j].seat,
					 advantages[j] * meanSamples / max(Float(batch[j].samples), 1))
				},
				b: b, t: t
			)
			var loss: Float = 0
			var windows = 0
			while true {
				let window = batcher.window()
				guard window.samples > 0 else { break }
				globalStep += 1
				let m = graph.step(window, lr: Net.correctedLR(lr, step: globalStep), update: true)
				batcher.carry(h: m.h, c: m.c)
				loss += m.loss
				windows += 1
			}
			loss /= Float(max(windows, 1))

			let stats = BatchStats(batch)
			print("iter \(iter)  \(stats.wins)W \(stats.losses)L \(stats.draws)D  R \(f(stats.meanR))  |A| \(f(meanAbs))  settle \(f(stats.settle))  units \(f(stats.units))  kills \(f(stats.kills))  prestige \(f(stats.prestige))  days \(stats.days)  samples \(stats.samples)  loss \(f(loss))\(schedule.difficulty > 0 ? "  d \(f(schedule.difficulty))" : "")")

			if let move = schedule.update(winRate: Float(stats.wins) / n) {
				print("  \(move)")
			}

			var arena = ""
			if iter % ckpt == 0 || iter == iters {
				arena = try dumpCheckpoint(
					graph.checkpoint(), iter: iter, outDir: outDir,
					evalN: evalN, suite: suite, batch: batch
				)
			}
			csv += "\(iter),\(stats.wins),\(stats.losses),\(stats.draws),\(stats.meanR),\(meanAbs),\(stats.settle),\(stats.units),\(stats.kills),\(stats.prestige),\(stats.days),\(stats.samples),\(loss),\(windows),\(schedule.difficulty),\(arena)\n"
			try csv.write(to: outDir.appendingPathComponent("rl-log.csv"), atomically: true, encoding: .utf8)
		}

		try graph.checkpoint().data().write(to: outDir.appendingPathComponent("policy.pgw"))
		let d = start.duration(to: clock.now).components
		print("── rl ──")
		print("  iters:    \(iters) (\(d.seconds)s, \(battleIndex - seed) episodes)")
		print("  suite:    \(suite.rawValue)")
		print("  out:      \(outDir.path)/policy.pgw")
	}

	/// The checkpoint tail shared by the RL and PPO loops: write the weights,
	/// run the argmax arena on the fixed eval configs, dump the batch's
	/// episodes as replays. Returns the arena win rate for the CSV column.
	static func dumpCheckpoint(
		_ snapshot: LSTMWeights,
		iter: Int,
		outDir: URL,
		evalN: Int,
		suite: RolloutSuite,
		batch: [Episode]
	) throws -> String {
		try snapshot.data().write(to: outDir.appendingPathComponent("ckpt-\(iter).pgw"))

		let tally = Eval.arena(weights: snapshot, configs: 0 ..< evalN, suite: suite)
		print("  arena \(tally.line)  illegal \(tally.illegal)")

		let epiDir = outDir.appendingPathComponent("episodes-\(iter)", isDirectory: true)
		try FileManager.default.createDirectory(at: epiDir, withIntermediateDirectories: true)
		for (j, e) in batch.enumerated() {
			try e.replay.write(to: epiDir.appendingPathComponent("epi-\(j)-seat\(e.seat)-\(e.outcome).pgr"))
		}
		return f(Float(100 * tally.winRate))
	}

	// MARK: - Episode collection

	/// Plays `count` episodes concurrently; every episode is fully determined
	/// by its battle index (config, map seed, sampling seed, policy seat, mix
	/// draw), so the batch is reproducible regardless of thread interleaving.
	/// `difficulty` is continuous: each episode plays at ⌊d⌋ or ⌈d⌉ with
	/// probability from the fractional part — discrete level steps proved to
	/// be cliffs (run 7: even the purely economic 3→2 step collapsed the win
	/// rate), mixing makes every anneal a gradual re-weighting of the batch.
	static func collect(
		weights: LSTMWeights,
		count: Int,
		startIndex: Int,
		temp: Float,
		difficulty: Float,
		suite: RolloutSuite
	) -> [Episode] {
		let base = Int(difficulty)
		let frac = difficulty - Float(base)
		var results = [Episode?](repeating: nil, count: count)
		unsafe results.withUnsafeMutableBufferPointer { buffer in
			let out = unsafe UnsafeSendable(buffer)
			DispatchQueue.concurrentPerform(iterations: count) { j in
				let index = startIndex + j
				var mix = D20(seed: 0xC0FF_EE00 &+ UInt64(bitPattern: Int64(index)))
				let level = base + (mix.uniform() < frac ? 1 : 0)
				unsafe out.value[j] = play(
					index: index, seat: j % 2,
					weights: weights, temp: temp, level: level, suite: suite
				)
			}
		}
		return results.compactMap { $0 }
	}

	/// The standard config with the policy seat's economy boosted by
	/// `level` (0 = untouched): the curriculum manufactures the captures
	/// and wins REINFORCE must *experience* before it can reinforce them.
	/// While boosted, config tier asymmetry is neutralized — a tier-0
	/// seat facing tier 3 is unwinnable whatever its prestige, and such
	/// batches poison the curriculum with hopeless losses (run-6 lesson:
	/// the 3→2 step reintroduced them and win starvation returned).
	static func config(
		index: Int,
		seat: Int,
		level: Int,
		suite: RolloutSuite
	) -> Replay {
		var replay = Rollouts.replay(index: index, suite: suite)
		guard level > 0 else { return replay }
		let tier = max(replay.seats[0].tier, replay.seats[1].tier)
		replay.seats[0].tier = tier
		replay.seats[1].tier = tier
		replay.seats[seat].prestige = .rich
		replay.seats[1 - seat].prestige = .poor
		if level >= 2 {
			replay.seats[seat].baseLevel = max(replay.seats[seat].baseLevel, 2)
			replay.seats[1 - seat].baseLevel = 0
		}
		if level >= 3 {
			replay.seats[seat].baseLevel = 5
			replay.seats[seat].tier = 3
			replay.seats[1 - seat].tier = 0
		}
		return replay
	}

	/// One sampled episode: the policy on `seat`, the heuristic opposite,
	/// rollout budgets, terminal reward from the final state.
	static func play(
		index: Int,
		seat: Int,
		weights: LSTMWeights,
		temp: Float,
		level: Int,
		suite: RolloutSuite
	) -> Episode {
		var replay = config(index: index, seat: seat, level: level, suite: suite)
		var sim = replay.makeSim()
		var policy = LSTMPolicy(weights: weights)
		var ai = AI.Plan()
		var rng = D20(seed: 0x5DEE_CE66 &+ UInt64(bitPattern: Int64(index)))
		var episode = Episode(replay: replay, seat: seat, level: level)

		let mine = replay.seats[seat].country.team
		let theirs = replay.seats[1 - seat].country.team
		let start = census(sim, mine: mine, theirs: theirs)
		var prev = (mine: start.mineValue, theirs: start.theirsValue,
		            mineUnits: start.mineUnits, theirsUnits: start.theirsUnits)
		var killed: Float = 0
		var lost: Float = 0
		var kills: Float = 0
		var deaths: Float = 0

		while replay.actions.count < Rollouts.maxActions {
			if sim.winner != nil { break }
			if sim.day > Rollouts.maxDays { break }

			let action: TacticalAction
			if sim.playerIndex == seat {
				action = policy.traced(for: sim) { logits, mask in
					sample(logits, mask, temp: temp, rng: &rng)
				}.0
				episode.samples += 1
			} else {
				action = sim.run(ai: &ai)
			}
			replay.actions.append(action)
			_ = sim.reduce(action)

			// Value only *decreases* through kills — purchases and arriving
			// reinforcements increase it, so accumulating the drops separates
			// combat results from economy.
			let cur = unitValues(sim, mine: mine)
			killed += max(0, prev.theirs - cur.theirs)
			lost += max(0, prev.mine - cur.mine)
			kills += max(0, prev.theirsUnits - cur.theirsUnits)
			deaths += max(0, prev.mineUnits - cur.mineUnits)
			prev = cur
		}
		replay.winner = sim.winner ?? .none
		replay.days = UInt16(sim.day)

		let end = census(sim, mine: mine, theirs: theirs)
		episode.settleTerm = clamp(
			Float((end.ownSettlements - end.theirsSettlements) - (start.ownSettlements - start.theirsSettlements))
			/ Float(max(start.settlements, 1))
		)
		episode.unitTerm = clamp(
			killed / max(start.theirsValue, 1) - lost / max(start.mineValue, 1)
		)
		episode.killTerm = clamp(
			kills / max(start.theirsUnits, 1) - deaths / max(start.mineUnits, 1)
		)
		let pMine = Float(sim.players[seat].prestige)
		let pTheirs = Float(sim.players[1 - seat].prestige)
		episode.prestigeTerm = (pMine - pTheirs) / max(pMine + pTheirs, 1)

		episode.reward = wSettlements * episode.settleTerm
			+ wUnits * episode.unitTerm
			+ wKills * episode.killTerm
			+ wPrestige * episode.prestigeTerm
		if replay.winner == mine {
			episode.reward += wOutcome
			episode.outcome = "W"
		} else if replay.winner == theirs {
			episode.reward -= wOutcome
			episode.outcome = "L"
		}
		episode.replay = replay
		return episode
	}

	struct Census {
		var mineValue: Float = 0
		var theirsValue: Float = 0
		var mineUnits: Float = 0
		var theirsUnits: Float = 0
		var ownSettlements = 0
		var theirsSettlements = 0
		var settlements = 0
	}

	/// Hp-weighted unit cost per side plus settlement control (neutral
	/// settlements count toward the total but neither side).
	static func census(_ sim: borrowing TacticalSim, mine: Team, theirs: Team) -> Census {
		var c = Census()
		let value = unitValues(sim, mine: mine)
		c.mineValue = value.mine
		c.theirsValue = value.theirs
		c.mineUnits = value.mineUnits
		c.theirsUnits = value.theirsUnits
		sim.settlements.forEach { xy in
			c.settlements += 1
			let team = sim.control[xy].team
			if team == mine { c.ownSettlements += 1 }
			else if team == theirs { c.theirsSettlements += 1 }
		}
		return c
	}

	static func unitValues(
		_ sim: borrowing TacticalSim, mine: Team
	) -> (mine: Float, theirs: Float, mineUnits: Float, theirsUnits: Float) {
		sim.units.reduceAlive(into: (
			mine: Float(0), theirs: Float(0), mineUnits: Float(0), theirsUnits: Float(0)
		)) { r, i, u in
			guard !sim.offMap(unit: i.uid) else { return }
			let v = Float(u.cost) * Float(u.hp) / 15
			if u.country.team == mine {
				r.mine += v
				r.mineUnits += 1
			} else {
				r.theirs += v
				r.theirsUnits += 1
			}
		}
	}

	static func clamp(_ v: Float) -> Float { max(-1, min(1, v)) }

	/// Masked softmax sample at temperature `temp` (≤ 0 degenerates to
	/// argmax); `nil` iff no mask bit is set — same contract as argmax.
	static func sample(_ logits: [Float], _ mask: [Bool], temp: Float, rng: inout D20) -> Int? {
		guard temp > 0 else { return LSTMPolicy.argmax(logits, mask) }

		var top = -Float.infinity
		for i in logits.indices where mask[i] { top = max(top, logits[i]) }
		guard top > -.infinity else { return nil }

		var total = 0.0
		for i in logits.indices where mask[i] {
			total += Double(expf((logits[i] - top) / temp))
		}
		var u = Double(rng.next() >> 11) * 0x1p-53 * total
		var last: Int?
		for i in logits.indices where mask[i] {
			u -= Double(expf((logits[i] - top) / temp))
			last = i
			if u <= 0 { return i }
		}
		return last // float round-off: fall back to the final legal index
	}
}

/// Wrapper that vouches for cross-thread use of a pointer whose disjoint
/// element writes are proven by construction (one index per iteration).
struct UnsafeSendable<T>: @unchecked Sendable {
	let value: T
	init(_ value: T) { self.value = value }
}
