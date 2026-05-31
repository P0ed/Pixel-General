import Testing
@testable import PG

struct TacticalTests {

	private static func players(
		types: [PlayerType] = [.human, .ai, .ai, .ai]
	) -> [Player] {
		let countries: [4 of Country] = [.swe, .usa, .rus, .pak]
		return types.enumerated().map { i, type in
			Player(country: countries[i], type: type, prestige: 0xF00)
		}
	}

	private static let goodSeed = 1

	@Test func factoryProducesValidState() {
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
		var cityCount = 0
		for xy in state.map.indices where state.map[xy] == .city { cityCount += 1 }
		#expect(cityCount > 0, "No cities placed")
		#expect(state.turn == 0)

		// Every alive unit must occupy a unique tile and the unitsMap must
		// agree with `position`. Collect violations into local arrays so
		// `#expect` doesn't have to capture `state` (which contains a
		// noncopyable `Map`).
		var seen: Set<XY> = []
		var outOfMapPositions: [XY] = []
		var collisions: [XY] = []
		var unitsMapMismatches: [XY] = []
		state.units.forEachAlive { i, u in
			let p = state.position[i]
			if !state.map.contains(p) { outOfMapPositions.append(p) }
			if !seen.insert(p).inserted { collisions.append(p) }
			if state.unitsMap[p] != i.uid { unitsMapMismatches.append(p) }
		}
		#expect(outOfMapPositions.isEmpty, "Out-of-map unit positions: \(outOfMapPositions)")
		#expect(collisions.isEmpty, "Tile collisions: \(collisions)")
		#expect(unitsMapMismatches.isEmpty, "unitsMap mismatches at: \(unitsMapMismatches)")

		// Every city is controlled by one of the players (or default for the
		// degenerate empty-map case).
		let playerCountries = Set(players.map { $0.country })
		var cityBadCountry: [Country] = []
		for xy in state.map.indices where state.map[xy] == .city {
			let c = state.control[xy]
			if !playerCountries.contains(c), c != .swe {
				cityBadCountry.append(c)
			}
		}
		#expect(cityBadCountry.isEmpty, "Cities with unexpected country: \(cityBadCountry)")
	}

	@Test func cursorMovementStaysInBounds() {
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

	@Test func selectingOwnUnitSetsSelectableMoves() {
		var state = TacticalState.make(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: Self.goodSeed
		)
		// Ensure player 0's vision covers their own units (init does this).
		let ownUnitPos = state.units.firstMapAlive { i, u in
			u.country == state.country && u.canMove ? state.position[i] : nil
		}
		guard let ownUnitPos else {
			Issue.record("No movable own unit found")
			return
		}

		_ = state.apply(.tile(ownUnitPos))
		#expect(state.selectedUnit != .none, "Selecting own unit's tile should select it")
		#expect(state.selectable != nil, "Selectable moves should be set for movable unit")
	}

	@Test func aiCanRunAndEndTurnWithoutCrash() {
		// Run several end-of-turn cycles on a state with all-AI players,
		// driving each turn via `runAI` until either the turn changes or we
		// exceed an iteration budget. We're not asserting the game ends; only
		// that the loop completes without a crash and that the turn counter
		// advances at least once.
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
			var ai = TacticalState.AI(turn: 0)
			let action = state.axis(ai: &ai)
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

	@Test func endTurnIncrementsTurnCounter() {
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

	@Test func movesForOwnUnitNotIncludeStartTile() {
		let state = TacticalState.make(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: Self.goodSeed
		)

		let pick = state.units.firstMapAlive { i, u in
			u.country == state.country && u.canMove ? i.uid : nil
		}
		guard let uid = pick else {
			Issue.record("No movable own unit found")
			return
		}
		#expect(
			!state.moves(for: uid)[state.position[uid]],
			"Movable unit's own tile must not be reachable"
		)
	}
}
