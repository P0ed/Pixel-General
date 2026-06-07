import Testing
import Foundation
@testable import COR

/// Performance harness for the tactical core.
///
/// Generates a map, drops two AI players on it, and drives both sides to the
/// AI's natural conclusion (one team eliminated) while timing the work. The
/// printed metrics are the point of the test: run it before and after an
/// optimization and compare `avg / battle` and `throughput` to see the effect.
///
/// It is deterministic — same seeds produce the same battles — so the numbers
/// are comparable across runs as long as the inputs below are unchanged.
struct TacticalPerformanceTests {

	// MARK: - Tunables
	//
	// Bump `runs` for a steadier average, or swap `countries` to profile a
	// different match-up. swe is axis, usa is allies, so both are driven by the
	// `axis` planner — `drive` still dispatches per team, so soviet countries
	// (rus/ind/irn) work here too.

	private static let countries: [Country] = [.swe, .usa]
	private static let runs = 5
	private static let mapSize = 32

	// Safety rails so a stalemate can't hang the suite. A real AI battle
	// finishes well under these.
	private static let maxActionsPerBattle = 200_000
	private static let maxDaysPerBattle = 400

	@Test func aiBattleResolutionPerformance() {
		var resolvedCount = 0
		var totalActions = 0
		var totalDuration: Duration = .zero

		let clock = ContinuousClock()

		for seed in 0..<Self.runs {
			var state = TacticalState.make(
				players: Self.countries.map { c in
					Player(country: c, type: .ai, prestige: 0xF00)
				},
				units: .small(Self.countries[0]) + .small(Self.countries[1]),
				size: Self.mapSize,
				seed: seed
			)

			// One shared plan is fine: `axis` rebuilds it whenever the turn
			// rolls over, i.e. once per player per round.
			var ai = TacticalState.AI()
			var actions = 0

			// Time only the resolution loop, not map generation (setup cost).
			let start = clock.now
			while actions < Self.maxActionsPerBattle {
				if state.aliveTeams.nonzeroBitCount <= 1 { break }	// resolved
				if state.day > Self.maxDaysPerBattle { break }		// stalemate guard
				let action = state.drive(&ai)
				_ = state.reduce(action)
				actions += 1
			}
			let elapsed = clock.now - start

			let resolved = state.aliveTeams.nonzeroBitCount <= 1
			if resolved { resolvedCount += 1 }
			totalActions += actions
			totalDuration += elapsed

			unsafe print(String(
				format: "  seed %d: %@ — %.3fs, %d actions, %d days (%.0f actions/s)",
				seed,
				resolved ? "resolved" : "UNRESOLVED",
				elapsed.seconds,
				actions,
				state.day,
				Double(actions) / max(elapsed.seconds, 1e-9)
			))
		}

		let secs = totalDuration.seconds
		unsafe print("""
		── TacticalMode AI-battle performance ──
		  match-up:      \(Self.countries.map(String.init(describing:)).joined(separator: " vs "))
		  map:           \(Self.mapSize)×\(Self.mapSize), \(Self.runs) runs
		  resolved:      \(resolvedCount)/\(Self.runs)
		  total time:    \(String(format: "%.3f", secs))s
		  avg / battle:  \(String(format: "%.3f", secs / Double(Self.runs)))s
		  total actions: \(totalActions)
		  throughput:    \(String(format: "%.0f", Double(totalActions) / max(secs, 1e-9))) actions/s
		""")

		#expect(
			resolvedCount == Self.runs,
			"Only \(resolvedCount)/\(Self.runs) battles resolved within the budget"
		)
	}
}

private extension TacticalState {
	/// Asks the correct AI generator for the current player's next action,
	/// mirroring the team dispatch in `TacticalState.run`.
	func drive(_ ai: inout AI) -> TacticalAction {
		switch player.country.team {
		case .soviet: soviet(ai: &ai)
		case .axis, .allies: axis(ai: &ai)
		}
	}
}

private extension Duration {
	/// Wall-clock seconds as a `Double` (the type has no built-in accessor).
	var seconds: Double {
		Double(components.seconds) + Double(components.attoseconds) / 1e18
	}
}
