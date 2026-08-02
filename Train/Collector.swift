import Foundation
import COR

/// Episode collection for the PPO trainer: each batch plays sampled episodes
/// against the frozen heuristic with masked-softmax *sampling* (own `D20`
/// instance — the sim's is never touched), scores them with the dense reward,
/// and records the per-decision slices GAE consumes. Also home of the reward
/// weights, self-paced curriculum, and checkpoint tail the training loop uses.
///
/// Reward: dense, symmetric progress terms — win/loss alone starves policy
/// gradients when the sampled win rate is ~0 (run-2 lesson: the policy
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
///   outcome      ±wOutcome on a decided battle; a timeout costs −wDraw so
///                stalling out the clock cannot dominate playing for the win
/// Argmax arena checkpoints (`Eval.play`, battle indices 0…) track real
/// strength on the same configs `Train eval` reports.
enum Collector {

	static let wOutcome: Float = 0.47
	static let wDraw: Float = 0.2
	static let wSettlements: Float = 0.47
	static let wUnits: Float = 0.1
	static let wKills: Float = 0.33
	static let wPrestige: Float = 0.022

	struct Episode {
		var replay: Replay
		var seat: Int
		var level = 0
		var reward: Float = 0
		/// One slice per policy decision, in stream order: the shaping earned
		/// between that decision and the next (outcome + prestige on the last).
		var stepRewards: [Float] = []
		var outcome = "D"
		var samples = 0
		var settleTerm: Float = 0
		var unitTerm: Float = 0
		var killTerm: Float = 0
		var prestigeTerm: Float = 0
	}

	/// Per-iteration aggregates over a collected batch — the numbers the
	/// training loop prints and logs.
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
	/// way back down.
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

	/// The checkpoint tail: write the weights, run the argmax arena on the
	/// fixed eval configs, dump the batch's episodes as replays. Returns the
	/// arena win rate for the CSV column.
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
	/// and wins the policy must *experience* before it can reinforce them.
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
	/// rollout budgets, episode reward from the final state plus the
	/// per-decision slices PPO's GAE consumes.
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
		var prev = start
		var killed: Float = 0
		var lost: Float = 0
		var kills: Float = 0
		var deaths: Float = 0
		// Per-step slices are deltas of the *clamped cumulative* weighted terms,
		// so they telescope to exactly the episode's dense reward — `shaped` is
		// that cumulative value, `pending` the part accrued since the last
		// policy decision (shaping before the first decision is nobody's).
		var shaped: Float = 0
		var pending: Float = 0

		while replay.actions.count < Rollouts.maxActions {
			if sim.winner != nil { break }
			if sim.day > Rollouts.maxDays { break }

			let action: TacticalAction
			if sim.playerIndex == seat {
				if !episode.stepRewards.isEmpty {
					episode.stepRewards[episode.stepRewards.count - 1] += pending
				}
				pending = 0
				action = policy.traced(for: sim) { logits, mask in
					sample(logits, mask, temp: temp, rng: &rng)
				}.0
				episode.samples += 1
				episode.stepRewards.append(0)
			} else {
				action = sim.run(ai: &ai)
			}
			replay.actions.append(action)
			_ = sim.reduce(action)

			// Value only *decreases* through kills — purchases and arriving
			// reinforcements increase it, so accumulating the drops separates
			// combat results from economy.
			let cur = census(sim, mine: mine, theirs: theirs)
			killed += max(0, prev.theirsValue - cur.theirsValue)
			lost += max(0, prev.mineValue - cur.mineValue)
			kills += max(0, prev.theirsUnits - cur.theirsUnits)
			deaths += max(0, prev.mineUnits - cur.mineUnits)
			prev = cur

			episode.settleTerm = clamp(
				Float((cur.ownSettlements - cur.theirsSettlements) - (start.ownSettlements - start.theirsSettlements))
				/ Float(max(start.settlements, 1))
			)
			episode.unitTerm = clamp(
				killed / max(start.theirsValue, 1) - lost / max(start.mineValue, 1)
			)
			episode.killTerm = clamp(
				kills / max(start.theirsUnits, 1) - deaths / max(start.mineUnits, 1)
			)
			let w = wSettlements * episode.settleTerm
				+ wUnits * episode.unitTerm
				+ wKills * episode.killTerm
			pending += w - shaped
			shaped = w
		}
		replay.winner = sim.winner ?? .none
		replay.days = UInt16(sim.day)

		let pMine = Float(sim.players[seat].prestige)
		let pTheirs = Float(sim.players[1 - seat].prestige)
		episode.prestigeTerm = (pMine - pTheirs) / max(pMine + pTheirs, 1)

		episode.reward = shaped + wPrestige * episode.prestigeTerm
		var terminal = wPrestige * episode.prestigeTerm
		if replay.winner == mine {
			episode.reward += wOutcome
			terminal += wOutcome
			episode.outcome = "W"
		} else if replay.winner == theirs {
			episode.reward -= wOutcome
			terminal -= wOutcome
			episode.outcome = "L"
		} else {
			episode.reward -= wDraw
			terminal -= wDraw
		}
		if !episode.stepRewards.isEmpty {
			episode.stepRewards[episode.stepRewards.count - 1] += pending + terminal
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
