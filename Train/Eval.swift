import Foundation
import COR

/// `Train eval` — the arena. The pure-Swift `LSTMPolicy` (the exact code path
/// the app ships) plays the frozen heuristic `run(ai:)`. Each battle config
/// from `Rollouts.replay(index:)` is played twice with sides swapped, so map
/// generation, economy, and roster asymmetries cancel out of the win rate.
///
/// Reported: win/draw/loss per side and overall, average days, and the
/// illegal-action count — a non-`.end` policy action that leaves `encode(sim)`
/// unchanged no-opped through `reduce`, which the masks are supposed to make
/// impossible; any hit fails the run.
enum Eval {

	struct Tally {
		var wins = 0
		var losses = 0
		var draws = 0
		var days = 0
		var battles = 0
		var actions = 0
		var illegal = 0

		var winRate: Double { battles == 0 ? 0 : Double(wins) / Double(battles) }

		mutating func add(_ other: Tally) {
			wins += other.wins
			losses += other.losses
			draws += other.draws
			days += other.days
			battles += other.battles
			actions += other.actions
			illegal += other.illegal
		}

		var line: String {
			let days = battles == 0 ? 0 : Double(self.days) / Double(battles)
			return "\(wins)W \(draws)D \(losses)L of \(battles)  " +
				"win \(unsafe String(format: "%.1f", 100 * winRate))%  " +
				"avg days \(unsafe String(format: "%.1f", days))  " +
				"\(actions) actions  \(illegal) illegal"
		}
	}

	struct Match {
		var policy: Tally
		var heuristic: Tally
	}

	static func run(_ args: [String]) throws {
		var n = 32
		var seedBase = 0
		var weightsPath: String?
		var wseed: Int?
		var suite: RolloutSuite = .mixed

		try Args(args).parse { flag, next in
			switch flag {
			case "--n": n = try Int(next()) ?? n
			case "--seed": seedBase = try Int(next()) ?? seedBase
			case "--weights": weightsPath = try next()
			case "--wseed": wseed = try Int(next())
			case "--suite": suite = try .parse(next())
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		let weights: LSTMWeights
		if let weightsPath {
			weights = try LSTMWeights.load(weightsPath)
		} else if let wseed {
			weights = .random(seed: UInt64(wseed))
		} else {
			throw TrainError.usage("eval needs --weights <pgw> (or --wseed <n> for a random-weight baseline)")
		}

		var policy = LSTMPolicy(weights: weights)

		let clock = ContinuousClock()
		let start = clock.now
		var bySeat = [Tally(), Tally()]
		var heuristic = Tally()

		for index in seedBase ..< seedBase + n {
			let config = Rollouts.replay(index: index, suite: suite)
			var results: [String] = []

			for seat in 0 ..< config.seats.count {
				let match = play(config, policySeat: seat, policy: &policy, heuristicOracle: true)
				bySeat[seat].add(match.policy)
				heuristic.add(match.heuristic)
				let outcome = match.policy.wins > 0 ? "W" : match.policy.losses > 0 ? "L" : "D"
				results.append("seat \(seat): \(outcome) \(match.policy.days)d")
			}

			let seats = config.seats.map { s in "\(s.country)" }.joined(separator: " vs ")
			print("  \(index): \(seats) \(config.size)x\(config.size) | \(results.joined(separator: " | "))")
		}

		var total = Tally()
		for tally in bySeat { total.add(tally) }

		let d = start.duration(to: clock.now).components
		let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
		print("── eval ──")
		print("  weights:  \(weightsPath ?? "random(seed: \(wseed ?? 0))")")
		print("  suite:    \(suite.rawValue)")
		print("  battles:  \(total.battles) (\(n) configs x both sides, seed base \(seedBase))")
		print("  seat 0:   \(bySeat[0].line)")
		print("  seat 1:   \(bySeat[1].line)")
		print("  policy:   \(total.line)")
		print("  heuristic: \(heuristic.line)")
		print("  time:     \(Int(secs))s")

		guard total.illegal + heuristic.illegal == 0 else {
			throw TrainError.failed("eval gate: \(total.illegal) illegal policy and \(heuristic.illegal) illegal heuristic actions")
		}
	}

	/// Plays `configs` from both sides against `policy`, accumulating a
	/// tally — the fixed arena both `Train eval` and the RL trainer's
	/// checkpoints report.
	static func arena(
		policy: inout LSTMPolicy,
		configs: Range<Int>,
		suite: RolloutSuite
	) -> Tally {
		var tally = Tally()
		for index in configs {
			let config = Rollouts.replay(index: index, suite: suite)
			for seat in 0 ..< config.seats.count {
				tally.add(play(config, policySeat: seat, policy: &policy, heuristicOracle: false).policy)
			}
		}
		return tally
	}

	/// One battle: the policy on `policySeat`, the heuristic on the rest;
	/// same budgets as the rollout generator. Returns a single-battle tally
	/// per side. The mutation oracle (encode before/after `reduce`) always
	/// guards policy actions; `heuristicOracle` extends it to the heuristic's
	/// — the arena skips that, since it discards the heuristic tally.
	static func play(
		_ config: Replay,
		policySeat: Int,
		policy: inout LSTMPolicy,
		heuristicOracle: Bool
	) -> Match {
		var sim = config.makeSim()
		var ai = AI.Plan()
		policy.reset()

		var tallies = [Tally(), Tally()]	// [policy, heuristic]
		var actions = 0
		while actions < Rollouts.maxActions {
			if sim.winner != nil { break }
			if sim.day > Rollouts.maxDays { break }

			let side = sim.playerIndex == policySeat ? 0 : 1
			let action = side == 0 ? policy.action(for: sim) : sim.run(ai: &ai)
			tallies[side].actions += 1
			if action != .end, side == 0 || heuristicOracle {
				let before = encode(sim)
				_ = sim.reduce(action)
				if encode(sim) == before { tallies[side].illegal += 1 }
			} else {
				_ = sim.reduce(action)
			}
			actions += 1
		}

		let winner = sim.winner ?? .none
		let teams = [
			config.seats[policySeat].country.team,
			config.seats[1 - policySeat].country.team,
		]
		for side in 0 ..< 2 {
			if winner == teams[side] {
				tallies[side].wins = 1
			} else if winner == teams[1 - side] {
				tallies[side].losses = 1
			} else {
				tallies[side].draws = 1
			}
			tallies[side].days = Int(sim.day)
			tallies[side].battles = 1
		}
		return Match(policy: tallies[0], heuristic: tallies[1])
	}
}
