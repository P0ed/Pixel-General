import Foundation

/// `Train rl` — REINFORCE fine-tune of a BC checkpoint against the frozen
/// heuristic. Each iteration plays a batch of episodes with masked-softmax
/// *sampling* (own SplitMix64 — the sim's D20 is never touched), scores them
/// with a terminal reward, and replays them through the BC graph as
/// advantage-weighted cross-entropy — with `Σ|w|` normalization that is
/// exactly the policy gradient. The baseline is an EMA of episode returns;
/// advantages are normalized to mean |A| = 1 per batch (the graph divides by
/// Σ|w| per window, so this keeps every window's scale honest).
///
/// Reward: win +1 / loss −1 / timeout −0.2, plus 0.2 × the hp-weighted
/// unit-cost margin — so even a timeout draw rewards ending up ahead on
/// material. Argmax arena checkpoints (`Eval.play`, battle indices 0…) track
/// real strength on the same configs `Train eval` reports.
enum RLTrainer {

	struct Episode {
		var replay: Replay
		var seat: Int
		var reward: Float = 0
		var outcome = "D"
		var samples = 0
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

		var i = 0
		while i < args.count {
			func next() throws -> String {
				i += 1
				guard i < args.count else { throw TrainError.usage("missing value for \(args[i - 1])") }
				return args[i]
			}
			switch args[i] {
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
			default: throw TrainError.usage("unknown option \(args[i])")
			}
			i += 1
		}

		guard let weightsPath else {
			throw TrainError.usage("rl needs --weights <pgw> (a BC checkpoint)")
		}
		guard let weights = LSTMWeights(data: try Data(contentsOf: URL(fileURLWithPath: weightsPath))) else {
			throw TrainError.badFile(weightsPath)
		}

		TacticalState.logsMapGen = false
		let outDir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

		let graph = try BCGraph(weights: weights, b: b, t: t)
		var battleIndex = seed
		var baseline: Float?
		var globalStep = 0
		var csv = "iter,wins,losses,draws,meanR,baseline,days,samples,loss,windows,arenaWin\n"
		let clock = ContinuousClock()
		let start = clock.now

		for iter in 1 ... iters {
			// On-policy batch with the graph's current weights.
			let current = graph.checkpoint()
			let batch = collect(weights: current, count: episodes, startIndex: battleIndex, temp: temp)
			battleIndex += episodes

			let meanR = batch.reduce(0) { $0 + $1.reward } / Float(batch.count)
			let base = baseline ?? meanR
			baseline = 0.9 * base + 0.1 * meanR
			var advantages = batch.map { e in e.reward - base }
			let meanAbs = max(advantages.reduce(0) { $0 + abs($1) } / Float(advantages.count), 0.1)
			advantages = advantages.map { a in a / meanAbs }

			let batcher = Batcher(
				episodes: batch.indices.map { j in (batch[j].replay, batch[j].seat, advantages[j]) },
				b: b, t: t
			)
			var loss: Float = 0
			var windows = 0
			while true {
				let window = batcher.window()
				guard window.samples > 0 else { break }
				globalStep += 1
				let corrected = lr * (1 - powf(0.999, Float(globalStep))).squareRoot() / (1 - powf(0.9, Float(globalStep)))
				let m = graph.step(window, lr: corrected, update: true)
				batcher.carry(h: m.h, c: m.c)
				loss += m.loss
				windows += 1
			}
			loss /= Float(max(windows, 1))

			let wins = batch.count(where: { $0.outcome == "W" })
			let losses = batch.count(where: { $0.outcome == "L" })
			let draws = batch.count - wins - losses
			let days = batch.reduce(0) { $0 + Int($1.replay.days) } / batch.count
			let samples = batch.reduce(0) { $0 + $1.samples }
			print("iter \(iter)  \(wins)W \(losses)L \(draws)D  R \(f(meanR))  base \(f(base))  days \(days)  samples \(samples)  loss \(f(loss))")

			var arena = ""
			if iter % ckpt == 0 || iter == iters {
				let snapshot = graph.checkpoint()
				try snapshot.data().write(to: outDir.appendingPathComponent("ckpt-\(iter).pgw"))

				var policy = LSTMPolicy(weights: snapshot)
				var tally = Eval.Tally()
				for index in 0 ..< evalN {
					let config = Rollouts.replay(index: index)
					for seat in 0 ..< config.seats.count {
						tally.add(Eval.play(config, policySeat: seat, policy: &policy))
					}
				}
				arena = f(Float(100 * tally.winRate))
				print("  arena \(tally.line)  illegal \(tally.illegal)")

				let epiDir = outDir.appendingPathComponent("episodes-\(iter)", isDirectory: true)
				try FileManager.default.createDirectory(at: epiDir, withIntermediateDirectories: true)
				for (j, e) in batch.enumerated() {
					try e.replay.write(to: epiDir.appendingPathComponent("epi-\(j)-seat\(e.seat)-\(e.outcome).pgr"))
				}
			}
			csv += "\(iter),\(wins),\(losses),\(draws),\(meanR),\(base),\(days),\(samples),\(loss),\(windows),\(arena)\n"
			try csv.write(to: outDir.appendingPathComponent("rl-log.csv"), atomically: true, encoding: .utf8)
		}

		try graph.checkpoint().data().write(to: outDir.appendingPathComponent("policy.pgw"))
		let d = start.duration(to: clock.now).components
		print("── rl ──")
		print("  iters:    \(iters) (\(d.seconds)s, \(battleIndex - seed) episodes)")
		print("  out:      \(outDir.path)/policy.pgw")
	}

	private static func f(_ v: Float) -> String { unsafe String(format: "%.3f", v) }

	// MARK: - Episode collection

	/// Plays `count` episodes concurrently; every episode is fully determined
	/// by its battle index (config, map seed, sampling seed, policy seat), so
	/// the batch is reproducible regardless of thread interleaving.
	static func collect(weights: LSTMWeights, count: Int, startIndex: Int, temp: Float) -> [Episode] {
		var results = [Episode?](repeating: nil, count: count)
		unsafe results.withUnsafeMutableBufferPointer { buffer in
			let out = unsafe UnsafeSendable(buffer)
			DispatchQueue.concurrentPerform(iterations: count) { j in
				unsafe out.value[j] = play(
					index: startIndex + j, seat: j % 2,
					weights: weights, temp: temp
				)
			}
		}
		return results.compactMap { $0 }
	}

	/// One sampled episode: the policy on `seat`, the heuristic opposite,
	/// rollout budgets, terminal reward from the final state.
	static func play(index: Int, seat: Int, weights: LSTMWeights, temp: Float) -> Episode {
		var replay = Rollouts.replay(index: index)
		var state = replay.makeState()
		var policy = LSTMPolicy(weights: weights)
		var ai = TacticalSim.AI()
		var rng = Rand(s: 0x5DEE_CE66 &+ UInt64(bitPattern: Int64(index)))
		var episode = Episode(replay: replay, seat: seat)

		while replay.actions.count < Rollouts.maxActions {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }
			if state.sim.day > Rollouts.maxDays { break }

			let action: TacticalAction
			if state.sim.playerIndex == seat {
				action = policy.traced(for: state.sim) { logits, mask in
					sample(logits, mask, temp: temp, rng: &rng)
				}.0
				episode.samples += 1
			} else {
				action = state.sim.axis(ai: &ai)
			}
			replay.actions.append(action)
			_ = state.reduce(action)
		}
		replay.winner = state.sim.winner ?? .none
		replay.days = UInt16(state.sim.day)

		let mine = replay.seats[seat].country.team
		let theirs = replay.seats[1 - seat].country.team
		let bonus = 0.2 * margin(state, team: mine)
		if replay.winner == mine {
			episode.reward = 1 + bonus
			episode.outcome = "W"
		} else if replay.winner == theirs {
			episode.reward = -1 + bonus
			episode.outcome = "L"
		} else {
			episode.reward = -0.2 + bonus
			episode.outcome = "D"
		}
		episode.replay = replay
		return episode
	}

	/// Material margin ∈ [−1, 1]: hp-weighted unit cost, mine vs theirs.
	static func margin(_ state: borrowing TacticalState, team: Team) -> Float {
		let value = state.sim.units.reduceAlive(into: (mine: Float(0), theirs: Float(0))) { r, i, u in
			guard !state.sim.offMap(unit: i.uid) else { return }
			let v = Float(u.cost) * Float(u.hp) / 15
			if u.country.team == team {
				r.mine += v
			} else {
				r.theirs += v
			}
		}
		let total = value.mine + value.theirs
		return total > 0 ? (value.mine - value.theirs) / total : 0
	}

	/// Masked softmax sample at temperature `temp` (≤ 0 degenerates to
	/// argmax); `nil` iff no mask bit is set — same contract as argmax.
	static func sample(_ logits: [Float], _ mask: [Bool], temp: Float, rng: inout Rand) -> Int? {
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

	/// SplitMix64, deliberately separate from the sim's `D20`.
	struct Rand {
		var s: UInt64
		mutating func next() -> UInt64 {
			s &+= 0x9E37_79B9_7F4A_7C15
			var z = s
			z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
			z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
			return z ^ (z >> 31)
		}
	}
}

/// Wrapper that vouches for cross-thread use of a pointer whose disjoint
/// element writes are proven by construction (one index per iteration).
struct UnsafeSendable<T>: @unchecked Sendable {
	let value: T
	init(_ value: T) { self.value = value }
}
