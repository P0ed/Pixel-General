import Testing
@testable import PG

struct TacticalTests {

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

	@Test func cursorMovementStaysInBounds() {
		let state = TacticalState.make(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: Self.goodSeed
		)

		var ui = TacticalUI()
		ui.cursor = XY(0, 0)
		_ = ui.apply(.direction(.left), state)   // would go to -1, must clamp
		#expect(ui.cursor.x >= 0 && ui.cursor.y >= 0)

		ui.cursor = XY(state.map.size - 1, state.map.size - 1)
		_ = ui.apply(.direction(.right), state)  // would go past edge
		#expect(ui.cursor.x < state.map.size && ui.cursor.y < state.map.size)

		// A direction in-bounds should move the cursor by one.
		ui.cursor = XY(5, 5)
		_ = ui.apply(.direction(.up), state)
		#expect(ui.cursor == XY(5, 6))
	}

	@Test func selectingOwnUnitSetsSelectableMoves() {
		let state = TacticalState.make(
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

		var ui = TacticalUI()
		_ = ui.apply(.tile(ownUnitPos), state)
		#expect(ui.selectedUnit != nil, "Selecting own unit's tile should select it")
		#expect(ui.selectable != nil, "Selectable moves should be set for movable unit")
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

		var ui = TacticalUI()
		let initialTurn = state.turn
		var iterations = 0
		let maxIterations = 4_000

		outer: while iterations < maxIterations {
			let action = state.runAI()
			_ = state.reduce(action, ui: &ui)
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
		var ui = TacticalUI()
		let before = state.turn
		_ = state.reduce(.end, ui: &ui)
		#expect(state.turn == before + 1, "End-of-turn must advance the turn counter")
	}

	@Test func movesForOwnUnitIncludeStartTile() {
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
}
