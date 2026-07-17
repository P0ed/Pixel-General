import Foundation
import COR

enum RolloutSuite: String, Sendable {
	case fair
	case mixed

	static func parse(_ value: String) throws -> Self {
		guard let suite = Self(rawValue: value) else {
			throw TrainError.usage("--suite must be classic or mixed")
		}
		return suite
	}
}

/// Generates heuristic-vs-heuristic battles and stores them as replays.
/// Both seats are driven by the heuristic `run(ai:)` directly (the perf-test
/// pattern), so the corpus is uniform heuristic play. Every battle
/// is fully determined by its index: re-running produces byte-identical files.
enum Rollouts {

	static let pairs: [(Country, Country)] = [(.swe, .usa), (.nor, .isr), (.den, .irn)]
	static let prestiges: [(UInt16, UInt16)] = [(.poor, .poor), (.rich, .rich)]
	static let baseLevels: [(UInt8, UInt8)] = [(0, 0), (2, 2)/*, (2, 0), (0, 2)*/]
	static let tiers: [(UInt8, UInt8)] = [(3, 3), (2, 2)/*, (3, 2), (2, 3)*/]

	static let maxActions = 65_000
	static let maxDays = 60

	static func run(_ args: [String]) throws {
		var n = 8
		var out = "tmp/runs/replays"
		var seedBase = 0
		var verify = false
		var suite: RolloutSuite = .mixed

		try Args(args).parse { flag, next in
			switch flag {
			case "--n": n = try Int(next()) ?? n
			case "--out": out = try next()
			case "--seed": seedBase = try Int(next()) ?? seedBase
			case "--verify": verify = true
			case "--suite": suite = try .parse(next())
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		let dir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

		let clock = ContinuousClock()
		let start = clock.now
		var totalActions = 0
		var resolved = 0

		for index in seedBase ..< seedBase + n {
			var replay = Self.replay(index: index, suite: suite)
			play(&replay)

			let url = dir.appendingPathComponent(name(index))
			try replay.write(to: url)
			if verify { try Replay.check(url) }

			totalActions += replay.actions.count
			if replay.winner != .none { resolved += 1 }
			print("  \(name(index)): \(replay.seats[0].country) vs \(replay.seats[1].country), 32x32, \(replay.actions.count) actions, \(replay.days) days, winner: \(replay.winner)")
		}

		let d = start.duration(to: clock.now).components
		let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
		print("── rollouts ──")
		print("  battles:  \(n) (\(resolved) resolved)")
		print("  suite:    \(suite.rawValue)")
		print("  actions:  \(totalActions)")
		print("  time:     \(Int(secs))s (\(Int(Double(totalActions) / max(secs, 1e-9))) actions/s)")
		print("  out:      \(dir.path)")
	}

	/// Battle configuration derived purely from the index; strides are chosen
	/// so nearby indices vary the matchup before the economy knobs.
	static func replay(index: Int, suite: RolloutSuite) -> Replay {
		let pair = pairs[suite == .fair ? 0 : index % pairs.count]
		let prestige = prestiges[suite == .fair ? 0 : (index / 3) % prestiges.count]
		let level = baseLevels[suite == .fair ? 0 : (index / 6) % baseLevels.count]
		let tier = tiers[suite == .fair ? 0 : (index / 12) % tiers.count]
		var replay = Replay(
			seed: Int64(index),
			seats: [
				.init(country: pair.0, prestige: prestige.0, baseLevel: level.0, tier: tier.0),
				.init(country: pair.1, prestige: prestige.1, baseLevel: level.1, tier: tier.1),
			]
		)
		guard suite == .mixed else { return replay }

		let deadline: UInt16 = 40
		switch index % 3 {
		case 1:
			replay.objective = .survive(replay.seats[0].country.team, day: deadline)
			replay.forts = 1
		case 2:
			replay.objective = .survive(replay.seats[1].country.team, day: deadline)
			replay.forts = 1
		default:
			break
		}
		return replay
	}

	/// The proven headless loop (`TacticalPerformanceTests`), recording every action.
	static func play(_ replay: inout Replay) {
		var sim = replay.makeSim()
		var ai = AI.Plan()
		while replay.actions.count < maxActions {
			if sim.winner != nil { break }
			if sim.day > maxDays { break }
			let action = sim.run(ai: &ai)
			replay.actions.append(action)
			_ = sim.reduce(action)
		}
		replay.winner = sim.winner ?? .none
		replay.days = UInt16(sim.day)
	}

	static func name(_ index: Int) -> String {
		var s = String(index)
		while s.count < 6 { s = "0" + s }
		return "battle-\(s).pgr"
	}
}
