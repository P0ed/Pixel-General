import Foundation

/// `Train eval` — the arena. The pure-Swift `LSTMPolicy` (the exact code path
/// the app ships) plays the frozen heuristic `axis(ai:)`. Each battle config
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
			return "\(wins)W \(losses)L \(draws)D of \(battles)  " +
				"win \(unsafe String(format: "%.1f", 100 * winRate))%  " +
				"avg days \(unsafe String(format: "%.1f", days))"
		}
	}

	static func run(_ args: [String]) throws {
		var n = 32
		var seedBase = 0
		var weightsPath: String?
		var wseed: Int?

		var i = 0
		while i < args.count {
			func next() throws -> String {
				i += 1
				guard i < args.count else { throw TrainError.usage("missing value for \(args[i - 1])") }
				return args[i]
			}
			switch args[i] {
			case "--n": n = try Int(next()) ?? n
			case "--seed": seedBase = try Int(next()) ?? seedBase
			case "--weights": weightsPath = try next()
			case "--wseed": wseed = try Int(next())
			default: throw TrainError.usage("unknown option \(args[i])")
			}
			i += 1
		}

		let weights: LSTMWeights
		if let weightsPath {
			guard let w = LSTMWeights(data: try Data(contentsOf: URL(fileURLWithPath: weightsPath))) else {
				throw TrainError.badFile(weightsPath)
			}
			weights = w
		} else if let wseed {
			weights = .random(seed: UInt64(wseed))
		} else {
			throw TrainError.usage("eval needs --weights <pgw> (or --wseed <n> for a random-weight baseline)")
		}

		TacticalState.logsMapGen = false
		var policy = LSTMPolicy(weights: weights)

		let clock = ContinuousClock()
		let start = clock.now
		var bySeat = [Tally(), Tally()]

		for index in seedBase ..< seedBase + n {
			let config = Rollouts.replay(index: index)
			var results: [String] = []

			for seat in 0 ..< config.seats.count {
				let tally = play(config, policySeat: seat, policy: &policy)
				bySeat[seat].add(tally)
				let outcome = tally.wins > 0 ? "W" : tally.losses > 0 ? "L" : "D"
				results.append("seat \(seat): \(outcome) \(tally.days)d")
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
		print("  battles:  \(total.battles) (\(n) configs x both sides, seed base \(seedBase))")
		print("  seat 0:   \(bySeat[0].line)")
		print("  seat 1:   \(bySeat[1].line)")
		print("  overall:  \(total.line)")
		print("  actions:  \(total.actions) by policy, \(total.illegal) illegal")
		print("  time:     \(Int(secs))s")

		guard total.illegal == 0 else {
			throw TrainError.failed("eval gate: \(total.illegal) illegal policy actions — masks must make this impossible")
		}
	}

	/// One battle: the policy on `policySeat`, the heuristic on the rest;
	/// same budgets as the rollout generator. Returns a single-battle tally.
	static func play(_ config: Replay, policySeat: Int, policy: inout LSTMPolicy) -> Tally {
		var state = config.makeState()
		var ai = TacticalSim.AI()
		policy.reset()

		var tally = Tally()
		var actions = 0
		while actions < Rollouts.maxActions {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }
			if state.sim.day > Rollouts.maxDays { break }

			if state.sim.playerIndex == policySeat {
				let action = policy.action(for: state.sim)
				tally.actions += 1
				if action == .end {
					_ = state.reduce(action)
				} else {
					let before = encode(state.sim)
					_ = state.reduce(action)
					if encode(state.sim) == before { tally.illegal += 1 }
				}
			} else {
				_ = state.reduce(state.sim.axis(ai: &ai))
			}
			actions += 1
		}

		let winner = state.sim.winner ?? .none
		let mine = config.seats[policySeat].country.team
		let theirs = config.seats[1 - policySeat].country.team
		if winner == mine {
			tally.wins = 1
		} else if winner == theirs {
			tally.losses = 1
		} else {
			tally.draws = 1
		}
		tally.days = Int(state.sim.day)
		tally.battles = 1
		return tally
	}
}
