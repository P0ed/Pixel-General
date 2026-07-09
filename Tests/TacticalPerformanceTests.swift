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

	private static let countries: [Country] = [.fin, .rus]
	private static let runs = 8
	private static let mapSize = 24

	private static let maxActionsPerBattle = 65_000
	private static let maxDaysPerBattle = 128

	@Test func aiBattleResolutionPerformance() {
		var resolvedCount = 0
		var totalActions = 0
		var totalDuration: Duration = .zero

		let clock = ContinuousClock()

		for seed in 0..<Self.runs {
			var sim = TacticalSim(
				players: Self.countries.map { c in
					Player(
						country: c,
						type: .ai,
						prestige: c == .fin ? .rich : .poor,
						baseLevel: c == .fin ? 5 : 0
					)
				},
				units: .base(Self.countries[0], lvl: 5) + .base(Self.countries[1]),
				size: Self.mapSize,
				seed: seed
			)

			var ai = AI.Plan()
			var actions = 0

			let elapsed = clock.measure {
				while actions < Self.maxActionsPerBattle {
					if sim.aliveTeams.nonzeroBitCount <= 1 { break }	// resolved
					if sim.day > Self.maxDaysPerBattle { break }		// stalemate guard
					let action = sim.run(ai: &ai)
					_ = sim.reduce(action)
					actions += 1
				}
			}

			let resolved = sim.aliveTeams.nonzeroBitCount <= 1
			if resolved { resolvedCount += 1 }
			totalActions += actions
			totalDuration += elapsed

			unsafe print(String(
				format: "  seed %d: %@ — %.3fs, %d actions, %d days (%.0f actions/s)",
				seed,
				resolved ? "resolved" : "UNRESOLVED",
				elapsed.seconds,
				actions,
				sim.day,
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

		if totalActions != 7133 { print("Behaviour changed") }
		#expect(
			resolvedCount == Self.runs,
			"Only \(resolvedCount)/\(Self.runs) battles resolved within the budget"
		)
	}
}

private extension Duration {
	var seconds: Double {
		Double(components.seconds) + Double(components.attoseconds) / 1e18
	}
}
