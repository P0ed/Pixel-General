import Foundation

/// Generates heuristic-vs-heuristic battles and stores them as replays.
/// Both seats are driven by `axis(ai:)` directly (the perf-test pattern), so
/// the corpus is uniform axisAI play regardless of country teams. Every battle
/// is fully determined by its index: re-running produces byte-identical files.
enum Rollouts {

	static let pairs: [(Country, Country)] = [(.ger, .usa), (.fin, .isr), (.swe, .pak), (.ned, .usa)]
	static let prestiges: [(UInt16, UInt16)] = [(.poor, .poor), (.rich, .poor), (.poor, .rich), (.rich, .rich)]
	static let baseLevels: [(UInt8, UInt8)] = [(0, 0), (5, 0), (0, 5), (2, 2)]
	static let tiers: [(UInt8, UInt8)] = [(3, 3), (0, 0), (3, 0), (0, 3)]

	static let maxActions = 65_000
	static let maxDays = 128

	static func run(_ args: [String]) throws {
		var n = 8
		var out = "tmp/runs/replays"
		var seedBase = 0
		var verify = false

		try Args(args).parse { flag, next in
			switch flag {
			case "--n": n = try Int(next()) ?? n
			case "--out": out = try next()
			case "--seed": seedBase = try Int(next()) ?? seedBase
			case "--verify": verify = true
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		TacticalState.logsMapGen = false
		let dir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

		let clock = ContinuousClock()
		let start = clock.now
		var totalActions = 0
		var resolved = 0

		for index in seedBase ..< seedBase + n {
			var replay = Self.replay(index: index)
			play(&replay)

			let url = dir.appendingPathComponent(name(index))
			try replay.write(to: url)
			if verify { try Replay.check(url) }

			totalActions += replay.actions.count
			if replay.winner != .none { resolved += 1 }
			print("  \(name(index)): \(replay.seats[0].country) vs \(replay.seats[1].country), \(replay.size)x\(replay.size), \(replay.actions.count) actions, \(replay.days) days, winner: \(replay.winner)")
		}

		let d = start.duration(to: clock.now).components
		let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
		print("── rollouts ──")
		print("  battles:  \(n) (\(resolved) resolved)")
		print("  actions:  \(totalActions)")
		print("  time:     \(Int(secs))s (\(Int(Double(totalActions) / max(secs, 1e-9))) actions/s)")
		print("  out:      \(dir.path)")
	}

	/// Battle configuration derived purely from the index; strides are chosen
	/// so nearby indices vary the matchup before the economy knobs.
	static func replay(index: Int) -> Replay {
		let pair = pairs[index % pairs.count]
		let prestige = prestiges[(index / 4) % prestiges.count]
		let level = baseLevels[(index / 16) % baseLevels.count]
		let tier = tiers[(index / 64) % tiers.count]
		return Replay(
			size: index % 2 == 0 ? 24 : 32,
			seed: Int64(index),
			seats: [
				.init(country: pair.0, prestige: prestige.0, baseLevel: level.0, tier: tier.0),
				.init(country: pair.1, prestige: prestige.1, baseLevel: level.1, tier: tier.1),
			]
		)
	}

	/// The proven headless loop (`TacticalPerformanceTests`), recording every action.
	static func play(_ replay: inout Replay) {
		var state = replay.makeState()
		var ai = TacticalSim.AI()
		while replay.actions.count < maxActions {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }
			if state.sim.day > maxDays { break }
			let action = state.sim.axis(ai: &ai)
			replay.actions.append(action)
			_ = state.reduce(action)
		}
		replay.winner = state.sim.winner ?? .none
		replay.days = UInt16(state.sim.day)
	}

	static func name(_ index: Int) -> String {
		var s = String(index)
		while s.count < 6 { s = "0" + s }
		return "battle-\(s).pgr"
	}
}
