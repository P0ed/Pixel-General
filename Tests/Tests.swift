import Dispatch
import Testing
@testable import PG

// MARK: - Deadline runner
//
// Map generation has at least one known failure mode where `placeRivers` can
// loop without ever reaching the river's `end` for some seeds. To keep the
// test suite from hanging while still surfacing those seeds, we run each
// generation on a background queue and wait with a deadline. Threads that miss
// the deadline are abandoned — they keep running until the test process exits,
// but the suite makes progress.
//
// `Foundation` is intentionally not imported: it pulls in `NSUnit`, which
// collides with `PG.Unit`.

private func runWithDeadline(
	_ deadline: Double,
	_ work: @escaping @Sendable () -> Void
) -> Bool {
	let semaphore = DispatchSemaphore(value: 0)
	DispatchQueue.global(qos: .userInitiated).async {
		work()
		semaphore.signal()
	}
	return semaphore.wait(timeout: .now() + deadline) == .success
}

// MARK: - Existing tests

struct Tests {

	@Test func randomDistribution() async throws {
		var d20 = D20()
		var bins = [20 of UInt16](repeating: 0)

		let throwsCount = 65_000
		let expected = throwsCount / 21

		(0 ..< throwsCount).forEach { i in
			bins[d20()] += 1
		}

		let str = bins.indices
			.map { i in "\(bins[i])" }
			.joined(separator: ", ")

		let result = bins.indices
			.reduce(true) { r, i in r && bins[i] > expected }

		print("Bins: \(str)")
		print("Each bin is expected to be greater than: \(expected)")
		#expect(result)
	}
}

// MARK: - Map generation

struct MapGenerationTests {

	private static let perSeedDeadline: Double = 8

	@Test func terminatesAcrossManySeeds() {
		var hangingSeeds: [Int] = []

		for seed in 0 ..< 96 {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				_ = Map<Terrain>(size: 32, seed: seed)
			}
			if !finished { hangingSeeds.append(seed) }
		}

		#expect(
			hangingSeeds.isEmpty,
			"Seeds that exceeded \(Self.perSeedDeadline)s during generation: \(hangingSeeds)"
		)
	}

	@Test func producesNonEmptyMapWithCitiesAndRivers() {
		// Seed-keyed observations recorded inside each closure. Access is
		// sequential — the main thread blocks on a semaphore until each
		// closure signals — so no lock is needed, only the unsafe-isolation
		// hint to satisfy strict concurrency.
		nonisolated(unsafe) var emptySeeds: [Int] = []
		nonisolated(unsafe) var noCitySeeds: [Int] = []
		nonisolated(unsafe) var noRiverSeeds: [Int] = []

		for seed in 0 ..< 32 {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: 32, seed: seed)
				var hasNonZero = false
				var hasCity = false
				var hasRiver = false
				for xy in map.indices {
					let t = map[xy]
					if t != .none { hasNonZero = true }
					if t == .city { hasCity = true }
					if t.isRiver { hasRiver = true }
				}
				if !hasNonZero { emptySeeds.append(seed) }
				if !hasCity { noCitySeeds.append(seed) }
				if !hasRiver { noRiverSeeds.append(seed) }
			}
			#expect(finished, "Seed \(seed) hung at generation")
		}

		#expect(emptySeeds.isEmpty, "Seeds that produced an all-`.none` map: \(emptySeeds)")
		#expect(noCitySeeds.isEmpty, "Seeds with no city: \(noCitySeeds)")
		#expect(noRiverSeeds.isEmpty, "Seeds with no river: \(noRiverSeeds)")
	}

	@Test func isDeterministicForSameSeed() {
		// Cells are compared inside a single closure because Map is ~Copyable
		// and cannot escape; we compare two generations directly.
		// Seeds known to hang at river creation (42, 77) are excluded so this
		// test stays focused on the determinism property.
		for seed in [0, 1, 7, 100, 999, 1023] {
			let finished = runWithDeadline(Self.perSeedDeadline * 2) {
				let a = Map<Terrain>(size: 32, seed: seed)
				let b = Map<Terrain>(size: 32, seed: seed)
				for xy in a.indices {
					if a[xy] != b[xy] {
						Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
						break
					}
				}
			}
			#expect(finished, "Seed \(seed) hung at generation")
		}
	}

	@Test func handlesPlayableSizes() {
		// `placeCities` computes `dw = (size - 8) / (div - 1) - 1` with
		// `div = size / 8`, so `div - 1 == 0` when `size < 16`, causing a
		// divide-by-zero crash. Cover only the sizes that don't trip that.
		// `placeRivers` branches on `riversCount == 1` (count <= 288 cells)
		// vs the multi-river setup, so size 16 still exercises both regimes.
		for size in [16, 20, 24, 32] {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: size, seed: 0)
				#expect(map.size == size)
				#expect(map.count == size * size)
			}
			#expect(finished, "Size \(size) seed 0 hung")
		}
	}

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors (after `shapeRivers`). Diagonal-only adjacency
		// would mean the river was disconnected.
		for seed in [3, 11, 23] {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: 32, seed: seed)
				for xy in map.indices where map[xy].isRiver {
					let n4 = xy.n4
					var connected = false
					for i in n4.indices {
						let p = n4[i]
						if map.contains(p), map[p].isRiver || map[p].isBridge {
							connected = true; break
						}
					}
					if !connected {
						Issue.record("Isolated river tile at \(xy) for seed \(seed)")
					}
				}
			}
			#expect(finished, "Seed \(seed) hung")
		}
	}
}

// MARK: - Tactical mode

struct TacticalTests {

	private static let perSeedDeadline: Double = 12

	private static func players(
		types: [4 of PlayerType] = [.human, .ai, .ai, .ai]
	) -> [4 of Player] {
		let countries: [4 of Country] = [.swe, .usa, .rus, .pak]
		return [4 of Player].init { i in
			Player(country: countries[i], type: types[i], alive: true, prestige: 0xF00)
		}
	}

	private static let goodSeed = 1

	@Test func factoryProducesValidState() {
		let finished = runWithDeadline(Self.perSeedDeadline) {
			let players = Self.players()
			let units = Array<Unit>.small(.swe)
			let state = TacticalState.make(
				players: players,
				units: units,
				size: 32,
				seed: Self.goodSeed
			)

			#expect(state.map.size == 32)
			#expect(state.players.count == 4)
			#expect(state.units.count > 0, "No units placed")
			#expect(state.buildings.count > 0, "No buildings placed")
			#expect(state.turn == 0)

			// Every alive unit must occupy a unique tile and the unitsMap must
			// agree with `position`. Collect violations into local arrays so
			// `#expect` doesn't have to capture `state` (which contains a
			// noncopyable `Map`).
			var seen: Set<XY> = []
			var outOfMapPositions: [XY] = []
			var collisions: [XY] = []
			var unitsMapMismatches: [XY] = []
			state.units.forEach { i, u in
				guard u.alive else { return }
				let p = state.position[i]
				if !state.map.contains(p) { outOfMapPositions.append(p) }
				if !seen.insert(p).inserted { collisions.append(p) }
				if state.unitsMap[p] != i.uid { unitsMapMismatches.append(p) }
			}
			#expect(outOfMapPositions.isEmpty, "Out-of-map unit positions: \(outOfMapPositions)")
			#expect(collisions.isEmpty, "Tile collisions: \(collisions)")
			#expect(unitsMapMismatches.isEmpty, "unitsMap mismatches at: \(unitsMapMismatches)")

			// Every building's country is one of the players or .swe (default
			// for unaligned airfields), and lies within the map.
			let playerCountries = Set(players.map { $0.country })
			var buildingsOutOfMap: [XY] = []
			var buildingsBadCountry: [Country] = []
			state.buildings.forEach { _, b in
				if !state.map.contains(b.position) { buildingsOutOfMap.append(b.position) }
				if !playerCountries.contains(b.country), b.country != .swe {
					buildingsBadCountry.append(b.country)
				}
			}
			#expect(buildingsOutOfMap.isEmpty, "Buildings out of map: \(buildingsOutOfMap)")
			#expect(buildingsBadCountry.isEmpty, "Buildings with unexpected country: \(buildingsBadCountry)")
		}
		#expect(finished, "Tactical state factory hung")
	}

	@Test func cursorMovementStaysInBounds() {
		let finished = runWithDeadline(Self.perSeedDeadline) {
			var state = TacticalState.make(
				players: Self.players(),
				units: Array<Unit>.small(.swe),
				size: 32,
				seed: Self.goodSeed
			)

			state.cursor = XY(0, 0)
			_ = state.apply(.direction(.left))   // would go to -1, must clamp
			#expect(state.cursor.x >= 0 && state.cursor.y >= 0)

			state.cursor = XY(state.map.size - 1, state.map.size - 1)
			_ = state.apply(.direction(.right))  // would go past edge
			#expect(state.cursor.x < state.map.size && state.cursor.y < state.map.size)

			// A direction in-bounds should move the cursor by one.
			state.cursor = XY(5, 5)
			_ = state.apply(.direction(.up))
			#expect(state.cursor == XY(5, 6))
		}
		#expect(finished, "cursor input hung")
	}

	@Test func selectingOwnUnitSetsSelectableMoves() {
		let finished = runWithDeadline(Self.perSeedDeadline) {
			var state = TacticalState.make(
				players: Self.players(),
				units: Array<Unit>.small(.swe),
				size: 32,
				seed: Self.goodSeed
			)
			// Ensure player 0's vision covers their own units (init does this).
			let ownUnitPos = state.units.firstMap { i, u in
				u.country == state.country && u.canMove ? state.position[i] : nil
			}
			guard let ownUnitPos else {
				Issue.record("No movable own unit found")
				return
			}

			_ = state.apply(.tile(ownUnitPos))
			#expect(state.selectedUnit != nil, "Selecting own unit's tile should select it")
			#expect(state.selectable != nil, "Selectable moves should be set for movable unit")
		}
		#expect(finished, "select-own-unit input hung")
	}

	@Test func aiCanRunAndEndTurnWithoutCrash() {
		// Run several end-of-turn cycles on a state with all-AI players,
		// driving each turn via `runAI` until either the turn changes or we
		// exceed an iteration budget. We're not asserting the game ends; only
		// that the loop completes without a crash and that the turn counter
		// advances at least once.
		let finished = runWithDeadline(Self.perSeedDeadline * 3) {
			var state = TacticalState.make(
				players: Self.players(types: [.ai, .ai, .ai, .ai]),
				units: Array<Unit>.small(.swe),
				size: 32,
				seed: Self.goodSeed
			)

			let initialTurn = state.turn
			var iterations = 0
			let maxIterations = 4_000

			outer: while iterations < maxIterations {
				let action = state.runAI()
				_ = state.reduce(action)
				iterations += 1
				if action == .end {
					if state.turn > initialTurn + 4 {
						break outer
					}
				}
			}

			#expect(state.turn > initialTurn, "AI never advanced the turn counter")
			#expect(iterations < maxIterations, "AI loop hit iteration cap")
		}
		#expect(finished, "AI run hung")
	}

	@Test func endTurnIncrementsTurnCounter() {
		let finished = runWithDeadline(Self.perSeedDeadline) {
			var state = TacticalState.make(
				players: Self.players(types: [.ai, .ai, .ai, .ai]),
				units: Array<Unit>.small(.swe),
				size: 32,
				seed: Self.goodSeed
			)
			let before = state.turn
			_ = state.reduce(.end)
			#expect(state.turn == before + 1, "End-of-turn must advance the turn counter")
		}
		#expect(finished, "endTurn hung")
	}

	@Test func movesForOwnUnitIncludeStartTile() {
		let finished = runWithDeadline(Self.perSeedDeadline) {
			let state = TacticalState.make(
				players: Self.players(),
				units: Array<Unit>.small(.swe),
				size: 32,
				seed: Self.goodSeed
			)

			let pick = state.units.firstMap { i, u in
				u.country == state.country && u.canMove ? i.uid : nil
			}
			guard let uid = pick else {
				Issue.record("No movable own unit found")
				return
			}
			let moves = state.moves(for: uid)
			#expect(
				moves.moves[state.position[uid.index]] > 0,
				"Movable unit's own tile must be reachable"
			)
		}
		#expect(finished, "moves(for:) hung")
	}
}
