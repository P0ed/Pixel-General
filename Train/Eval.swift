import Foundation
import COR

/// `Train eval` — the arena. The pure-Swift `LSTMPolicy` (the exact code path
/// the app ships) plays the frozen heuristic `run(ai:)`. Each battle config
/// from `Rollouts.replay(index:)` is played twice with sides swapped, so map
/// generation, economy, and roster asymmetries cancel out of the win rate.
///
/// Reported: win/draw/loss per side and overall, average days, and the
/// illegal-action count. Independent battle/seat pairs run concurrently; their
/// results are folded and printed in config order, so throughput scales across
/// CPU cores without making the report nondeterministic. A non-`.end` action
/// that leaves `encode(sim)` unchanged no-opped through `reduce`, which the
/// masks are supposed to make impossible; any hit fails the run.
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
		var diag = Diag()
	}

	enum Decoder {
		/// `shipping` = `LSTMPolicy.action(for:)` (jointkind since 2026-08-02);
		/// `greedy` = the legacy stage-wise hierarchy via `traced`; the rest
		/// are `jointDecision` diagnostics.
		case shipping, greedy, exact, beam(Int), jointKind

		static func parse(_ s: String) throws -> Decoder {
			if s == "shipping" { return .shipping }
			if s == "greedy" { return .greedy }
			if s == "exact" { return .exact }
			if s == "jointkind" { return .jointKind }
			if s.hasPrefix("beam"), let n = Int(s.dropFirst(4)), n > 0 { return .beam(n) }
			throw TrainError.usage("--decoder shipping|greedy|exact|beam<N>|jointkind")
		}
	}

	/// Per-decision decoding diagnostics; all counters fold additively.
	struct Diag {
		var decisions = 0
		var disagree = 0
		var sameKindDiffActor = 0
		var sameKindDiffTarget = 0
		var beamMatchesExact = 0
		var transitions = [Int](repeating: 0, count: ActionSpace.kinds * ActionSpace.kinds)
		var kindCounts = [Int](repeating: 0, count: ActionSpace.kinds)
		var greedyKindCounts = [Int](repeating: 0, count: ActionSpace.kinds)
		var prefixes = 0
		var legalActions = 0
		var decodeSeconds = 0.0

		mutating func add(_ o: Diag) {
			decisions += o.decisions
			disagree += o.disagree
			sameKindDiffActor += o.sameKindDiffActor
			sameKindDiffTarget += o.sameKindDiffTarget
			beamMatchesExact += o.beamMatchesExact
			for i in transitions.indices { transitions[i] += o.transitions[i] }
			for i in kindCounts.indices { kindCounts[i] += o.kindCounts[i] }
			for i in greedyKindCounts.indices { greedyKindCounts[i] += o.greedyKindCounts[i] }
			prefixes += o.prefixes
			legalActions += o.legalActions
			decodeSeconds += o.decodeSeconds
		}
	}

	static func run(_ args: [String]) throws {
		var n = 32
		var seedBase = 0
		var weightsPath: String?
		var wseed: Int?
		var suite: RolloutSuite = .mixed
		var decoder: Decoder = .shipping

		try Args(args).parse { flag, next in
			switch flag {
			case "--n": n = try Int(next()) ?? n
			case "--seed": seedBase = try Int(next()) ?? seedBase
			case "--weights": weightsPath = try next()
			case "--wseed": wseed = try Int(next())
			case "--suite": suite = try .parse(next())
			case "--decoder": decoder = try .parse(next())
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

		let clock = ContinuousClock()
		let start = clock.now
		var bySeat = [Tally(), Tally()]
		var heuristic = Tally()
		var diag = Diag()
		let configs = seedBase ..< seedBase + n
		let matches = matches(
			weights: weights, configs: configs, suite: suite,
			heuristicOracle: true, decoder: decoder
		)

		for (offset, index) in configs.enumerated() {
			let config = Rollouts.replay(index: index, suite: suite)
			var results: [String] = []

			for seat in 0 ..< config.seats.count {
				let match = matches[offset * config.seats.count + seat]
				bySeat[seat].add(match.policy)
				heuristic.add(match.heuristic)
				diag.add(match.diag)
				let outcome = match.policy.wins > 0 ? "W" : match.policy.losses > 0 ? "L" : "D"
				results.append("seat \(seat): \(outcome) \(match.policy.days)d")
			}

			let seats = config.seats.map { s in "\(s.country)" }.joined(separator: " vs ")
			print("  \(index): \(seats) 32x32 | \(results.joined(separator: " | "))")
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
		printDiag(diag, decoder: decoder)

		guard total.illegal + heuristic.illegal == 0 else {
			throw TrainError.failed("eval gate: \(total.illegal) illegal policy and \(heuristic.illegal) illegal heuristic actions")
		}
	}

	/// Plays `configs` from both sides against `policy`, accumulating a
	/// tally — the fixed arena both `Train eval` and the RL trainer's
	/// checkpoints report.
	static func arena(
		weights: LSTMWeights,
		configs: Range<Int>,
		suite: RolloutSuite
	) -> Tally {
		var tally = Tally()
		for match in matches(
			weights: weights, configs: configs, suite: suite,
			heuristicOracle: false
		) {
			tally.add(match.policy)
		}
		return tally
	}

	/// Runs each (config, policy-seat) match with a fresh policy. `play`
	/// already reset the shared policy between serial matches; independent
	/// instances preserve those semantics and make parallel execution safe.
	private static func matches(
		weights: LSTMWeights,
		configs: Range<Int>,
		suite: RolloutSuite,
		heuristicOracle: Bool,
		decoder: Decoder = .shipping
	) -> [Match] {
		let seats = 2
		let count = configs.count * seats
		var results = [Match?](repeating: nil, count: count)
		unsafe results.withUnsafeMutableBufferPointer { buffer in
			let out = unsafe UnsafeSendable(buffer)
			DispatchQueue.concurrentPerform(iterations: count) { task in
				autoreleasepool {
					let index = configs.lowerBound + task / seats
					let seat = task % seats
					let config = Rollouts.replay(index: index, suite: suite)
					var policy = LSTMPolicy(weights: weights)
					unsafe out.value[task] = play(
						config, policySeat: seat, policy: &policy,
						heuristicOracle: heuristicOracle, decoder: decoder
					)
				}
			}
		}
		return results.map { $0! }
	}

	/// One battle: the policy on `policySeat`, the heuristic on the rest;
	/// same budgets as the rollout generator. Returns a single-battle tally
	/// per side. The mutation oracle (encode before/after `reduce`) always
	/// guards policy actions; `heuristicOracle` extends it to the heuristic's —
	/// checkpoint arenas skip that extra bookkeeping because they discard the
	/// heuristic tally.
	static func play(
		_ config: Replay,
		policySeat: Int,
		policy: inout LSTMPolicy,
		heuristicOracle: Bool,
		decoder: Decoder = .shipping
	) -> Match {
		var sim = config.makeSim()
		var ai = AI.Plan()
		policy.reset()

		let clock = ContinuousClock()
		var diag = Diag()
		var tallies = [Tally(), Tally()]	// [policy, heuristic]
		var actions = 0
		while actions < Rollouts.maxActions {
			if sim.winner != nil { break }
			if sim.day > Rollouts.maxDays { break }

			let side = sim.playerIndex == policySeat ? 0 : 1
			let action: TacticalAction
			if side == 1 {
				action = sim.run(ai: &ai)
			} else {
				let t0 = clock.now
				switch decoder {
				case .shipping:
					action = policy.action(for: sim)
				case .greedy:
					action = policy.traced(for: sim).0
				case .exact, .beam, .jointKind:
					var width = 8
					if case .beam(let w) = decoder { width = w }
					let d = policy.jointDecision(for: sim, beamWidth: width)
					switch decoder {
					case .beam: action = d.beam
					case .jointKind: action = d.kindLocal
					default: action = d.exact
					}
					diag.disagree += action != d.greedy ? 1 : 0
					diag.beamMatchesExact += d.beam == d.exact ? 1 : 0
					diag.prefixes += d.prefixes
					diag.legalActions += d.legalActions
					if action != d.greedy,
					   let g = sim.actionIndices(d.greedy), let p = sim.actionIndices(action) {
						diag.transitions[g.kind.rawValue * ActionSpace.kinds + p.kind.rawValue] += 1
						if g.kind == p.kind {
							if g.actor != p.actor {
								diag.sameKindDiffActor += 1
							} else {
								diag.sameKindDiffTarget += 1
							}
						}
					}
					if let g = sim.actionIndices(d.greedy) {
						diag.greedyKindCounts[g.kind.rawValue] += 1
					}
				}
				let dt = t0.duration(to: clock.now).components
				diag.decodeSeconds += Double(dt.seconds) + Double(dt.attoseconds) / 1e18
				diag.decisions += 1
				if let p = sim.actionIndices(action) {
					diag.kindCounts[p.kind.rawValue] += 1
				}
			}
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
		return Match(policy: tallies[0], heuristic: tallies[1], diag: diag)
	}

	private static let kindNames = ["move", "embark", "disembark", "attack", "resupply", "purchase", "end"]

	private static func printDiag(_ d: Diag, decoder: Decoder) {
		guard d.decisions > 0 else { return }
		let n = Double(d.decisions)
		func pct(_ v: Int) -> String { unsafe String(format: "%.2f%%", 100 * Double(v) / n) }
		func freq(_ counts: [Int]) -> String {
			zip(kindNames, counts).map { "\($0) \(pct($1))" }.joined(separator: "  ")
		}
		print("── decoder ──")
		print("  decisions: \(d.decisions)  decode \(unsafe String(format: "%.2f", 1000 * d.decodeSeconds / n)) ms/decision (summed across threads)")
		print("  played kinds:  \(freq(d.kindCounts))")
		switch decoder {
		case .shipping, .greedy:
			return
		case .exact, .beam, .jointKind:
			print("  greedy kinds:  \(freq(d.greedyKindCounts))")
			print("  disagree with greedy: \(d.disagree) (\(pct(d.disagree)))  " +
				"same-kind actor Δ \(d.sameKindDiffActor)  target/slot Δ \(d.sameKindDiffTarget)")
			var width = 8
			if case .beam(let w) = decoder { width = w }
			print("  beam\(width) == exact: \(pct(d.beamMatchesExact))")
			print("  avg legal prefixes \(unsafe String(format: "%.1f", Double(d.prefixes) / n))  " +
				"avg legal actions \(unsafe String(format: "%.1f", Double(d.legalActions) / n))")
			var pairs: [(Int, Int)] = []
			for i in d.transitions.indices where d.transitions[i] > 0 { pairs.append((i, d.transitions[i])) }
			pairs.sort { $0.1 > $1.1 }
			let top = pairs.prefix(10).map { i, c in
				"\(kindNames[i / ActionSpace.kinds])→\(kindNames[i % ActionSpace.kinds]) \(c)"
			}
			print("  top switches:  \(top.joined(separator: "  "))")
			return
		}
	}
}
