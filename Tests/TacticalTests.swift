import Testing
@testable import COR

struct TacticalTests {

	private static func players(
		types: [PlayerType] = [.human, .ai, .ai, .ai]
	) -> [Player] {
		let countries: [4 of Country] = [.swe, .usa, .rus, .pak]
		return types.enumerated().map { i, type in
			Player(country: countries[i], type: type, prestige: 0xF00)
		}
	}

	@Test func factoryProducesValidState() {
		let players = Self.players()
		let units = Array<Unit>.small(.swe)
		let state = TacticalState(
			players: players,
			units: units,
			size: 32,
			seed: 0
		)

		#expect(state.sim.map.size == 32)
		#expect(state.sim.players.count == 4)
		#expect(state.sim.units.count > 0, "No units placed")
		var cityCount = 0
		for xy in state.sim.map.indices where state.sim.map[xy] == .city { cityCount += 1 }
		#expect(cityCount > 0, "No cities placed")
		#expect(state.sim.turn == 0)

		// Every alive unit must occupy a unique tile and the unitsMap must
		// agree with `position`. Collect violations into local arrays so
		// `#expect` doesn't have to capture `state` (which contains a
		// noncopyable `Map`).
		var seen: Set<XY> = []
		var outOfMapPositions: [XY] = []
		var collisions: [XY] = []
		var unitsMapMismatches: [XY] = []
		state.sim.units.forEachAlive { i, u in
			let p = state.sim.position[i]
			if !state.sim.map.contains(p) { outOfMapPositions.append(p) }
			if !seen.insert(p).inserted { collisions.append(p) }
			if state.sim.unitsMap[p] != i.uid { unitsMapMismatches.append(p) }
		}
		#expect(outOfMapPositions.isEmpty, "Out-of-map unit positions: \(outOfMapPositions)")
		#expect(collisions.isEmpty, "Tile collisions: \(collisions)")
		#expect(unitsMapMismatches.isEmpty, "unitsMap mismatches at: \(unitsMapMismatches)")

		// Every city is controlled by one of the players (or default for the
		// degenerate empty-map case).
		let playerCountries = Set(players.map { $0.country })
		var cityBadCountry: [Country] = []
		for xy in state.sim.map.indices where state.sim.map[xy] == .city {
			let c = state.sim.control[xy]
			if !playerCountries.contains(c), c != .swe {
				cityBadCountry.append(c)
			}
		}
		#expect(cityBadCountry.isEmpty, "Cities with unexpected country: \(cityBadCountry)")
	}

	@Test func cursorMovementStaysInBounds() {
		var state = TacticalState(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: 0
		)

		state.ui.cursor = XY(0, 0)
		_ = state.apply(.direction(.left))   // would go to -1, must clamp
		#expect(state.ui.cursor.x >= 0 && state.ui.cursor.y >= 0)

		state.ui.cursor = XY(state.sim.map.size - 1, state.sim.map.size - 1)
		_ = state.apply(.direction(.right))  // would go past edge
		#expect(state.ui.cursor.x < state.sim.map.size && state.ui.cursor.y < state.sim.map.size)

		// A direction in-bounds should move the cursor by one.
		state.ui.cursor = XY(5, 5)
		_ = state.apply(.direction(.up))
		#expect(state.ui.cursor == XY(5, 6))
	}

	@Test func selectingOwnUnitSetsSelectableMoves() {
		var state = TacticalState(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: 0
		)
		// Ensure player 0's vision covers their own units (init does this).
		let ownUnitPos = state.sim.units.firstMapAlive { i, u in
			u.country == state.sim.country && u.canMove ? state.sim.position[i] : nil
		}
		guard let ownUnitPos else {
			Issue.record("No movable own unit found")
			return
		}

		_ = state.apply(.tile(ownUnitPos))
		#expect(state.ui.selectedUnit != .none, "Selecting own unit's tile should select it")
		#expect(state.ui.selectable != nil, "Selectable moves should be set for movable unit")
	}

	@Test func aiCanRunAndEndTurnWithoutCrash() {
		// Run several end-of-turn cycles on a state with all-AI players,
		// driving each turn via `runAI` until either the turn changes or we
		// exceed an iteration budget. We're not asserting the game ends; only
		// that the loop completes without a crash and that the turn counter
		// advances at least once.

		var ai = TacticalSim.AI()

		var state = TacticalState(
			players: TacticalTests.players(types: [.ai, .ai, .ai, .ai]),
			units: .small(.swe) + .small(.usa) + .small(.rus) + .small(.pak),
			size: 32,
			seed: 0
		)

		let initialTurn = state.sim.turn
		var iterations = 0
		let maxIterations = 1024

		while iterations < maxIterations {
			let action = state.sim.axis(ai: &ai)
			_ = state.reduce(action)
			iterations += 1
			if action == .end {
				if state.sim.turn > initialTurn + 4 {
					break
				}
			}
		}

		#expect(state.sim.turn > initialTurn, "AI never advanced the turn counter")
		#expect(iterations < maxIterations, "AI loop hit iteration cap")
	}

	@Test func endTurnIncrementsTurnCounter() {
		var state = TacticalState(
			players: Self.players(types: [.ai, .ai, .ai, .ai]),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: 0
		)
		let before = state.sim.turn
		_ = state.reduce(.end)
		#expect(state.sim.turn == before + 1, "End-of-turn must advance the turn counter")
	}

	@Test func helicopterEmbarkThenMoveKeepsPositionInSync() {
		// Repro: a 2-MP transport helicopter moves toward an elite infantry,
		// embarks it, then moves again. The sim position after the second move
		// must match the last tile of the emitted move event (what the sprite
		// animates to).
		let map = Map<32, Terrain>(size: 32, zero: .field)
		let players = [Player(country: .usa, type: .human, prestige: 0xF00)]
		var heli = Unit(model: .mh6, country: .usa)
		heli.reset()
		var inf = Unit(model: .delta, country: .usa)
		inf.reset()

		var sim = TacticalSim(map: map, players: players, cities: [], units: [heli, inf])

		let heliUID = sim.units.firstMapAlive { i, u in u.type == .heli ? i.uid : nil }!
		let infUID = sim.units.firstMapAlive { i, u in u.type == .inf ? i.uid : nil }!

		// Lay the two units out on open ground with full vision.
		sim.unitsMap[sim.position[heliUID]] = .none
		sim.unitsMap[sim.position[infUID]] = .none
		sim.position[heliUID.index] = XY(15, 10)
		sim.position[infUID.index] = XY(18, 10)
		sim.unitsMap[XY(15, 10)] = heliUID
		sim.unitsMap[XY(18, 10)] = infUID
		sim.players.modifyEach { _, p in p.visible = .full }

		#expect(sim.units[heliUID].mp == 2, "Helicopter should start with 2 MP")

		// Move 1: helicopter flies adjacent to the infantry.
		var e1: [TacticalEvent] = []
		sim.move(unit: heliUID, to: XY(17, 10), into: &e1)
		#expect(sim.position[heliUID] == XY(17, 10), "First move should land the heli adjacent to inf")
		#expect(sim.units[heliUID].mp == 1, "First move should consume one MP")

		// Embark the infantry into the helicopter.
		var e2: [TacticalEvent] = []
		sim.embark(unit: infUID, transport: heliUID, into: &e2)
		#expect(sim.cargo[heliUID] == infUID, "Infantry should be loaded")

		// Move 2: helicopter flies on with cargo aboard.
		var e3: [TacticalEvent] = []
		sim.move(unit: heliUID, to: XY(13, 10), into: &e3)

		// The emitted move event's final tile = what the sprite animates to.
		let heliMove = e3.first { event in
			if case let .move(uid, _) = event, uid == heliUID { return true }
			return false
		}
		guard case let .move(_, path)? = heliMove else {
			Issue.record("Second move emitted no move event for the helicopter: \(e3)")
			return
		}
		let spriteDst = path[path.count - 1]
		#expect(
			sim.position[heliUID] == spriteDst,
			"Sim heli position \(sim.position[heliUID]) must match sprite destination \(spriteDst)"
		)
		#expect(sim.position[heliUID] == XY(13, 10), "Second move should reach the target")
		#expect(sim.position[infUID] == sim.position[heliUID], "Cargo must ride along with the transport")
	}

	@Test func helicopterEmbarkThenMoveFullUIFlow() {
		// Same scenario, but driven through the real input path
		// (apply -> reduce, with selection reconciliation) to mirror the UI.
		let map = Map<32, Terrain>(size: 32, zero: .field)
		let players = [Player(country: .usa, type: .human, prestige: 0xF00)]
		var heli = Unit(model: .mh6, country: .usa)
		heli.reset()
		var inf = Unit(model: .delta, country: .usa)
		inf.reset()

		var sim = TacticalSim(map: map, players: players, cities: [], units: [heli, inf])
		let heliUID = sim.units.firstMapAlive { i, u in u.type == .heli ? i.uid : nil }!
		let infUID = sim.units.firstMapAlive { i, u in u.type == .inf ? i.uid : nil }!
		sim.unitsMap[sim.position[heliUID]] = .none
		sim.unitsMap[sim.position[infUID]] = .none
		sim.position[heliUID.index] = XY(15, 10)
		sim.position[infUID.index] = XY(17, 10)
		sim.unitsMap[XY(15, 10)] = heliUID
		sim.unitsMap[XY(17, 10)] = infUID
		sim.players.modifyEach { _, p in p.visible = .full }

		var state = TacticalState(sim: consume sim)

		func step(_ input: Input) {
			let reaction = state.apply(input)
			if case let .action(action) = reaction { _ = state.reduce(action) }
		}

		step(.tile(XY(15, 10)))      // select helicopter
		step(.tile(XY(16, 10)))      // move 1: fly adjacent to infantry
		step(.tile(XY(17, 10)))      // select the infantry
		step(.tile(XY(16, 10)))      // embark infantry into the helicopter
		#expect(state.ui.selectedUnit == heliUID, "Transport should be selected after embark")
		step(.tile(XY(12, 10)))      // move 2: fly on with cargo

		#expect(
			state.sim.position[heliUID] == XY(12, 10),
			"Heli sim position after second move is \(state.sim.position[heliUID])"
		)

		// Tab to the next actionable unit; the cursor must land on the heli's
		// true position, not somewhere stale.
		step(.target(.next))
		#expect(
			state.ui.cursor == state.sim.position[heliUID],
			"Cursor \(state.ui.cursor) must match heli true position \(state.sim.position[heliUID])"
		)
	}

	@Test func interruptedMovePathMatchesStoppedPosition() {
		// A move ambushed by a hidden enemy on the *first* step must not emit a
		// move event whose path runs past where the unit actually stops. The
		// sprite animates the event's path; the sim stores `pos`. They must agree.
		let map = Map<32, Terrain>(size: 32, zero: .field)
		let players = [
			Player(country: .usa, type: .human, prestige: 0xF00),
			Player(country: .rus, type: .ai, prestige: 0xF00),
		]
		var heli = Unit(model: .mh6, country: .usa)
		heli.reset()
		var enemy = Unit(model: .regular, country: .rus)
		enemy.reset()

		var sim = TacticalSim(map: map, players: players, cities: [], units: [heli, enemy])
		let heliUID = sim.units.firstMapAlive { i, u in u.country == .usa ? i.uid : nil }!
		let enemyUID = sim.units.firstMapAlive { i, u in u.country == .rus ? i.uid : nil }!
		sim.unitsMap[sim.position[heliUID]] = .none
		sim.unitsMap[sim.position[enemyUID]] = .none
		sim.position[heliUID.index] = XY(15, 10)
		sim.position[enemyUID.index] = XY(16, 10)
		sim.unitsMap[XY(15, 10)] = heliUID
		sim.unitsMap[XY(16, 10)] = enemyUID
		// The mover can't see the enemy, so it walks into the ambush tile.
		sim.players.modifyEach { _, p in p.visible = .empty }

		// Move toward the fogged tile that (unknown to the mover) holds the enemy
		// on the very first step.
		var events: [TacticalEvent] = []
		sim.move(unit: heliUID, to: XY(16, 10), into: &events)

		let heliMove = events.first { event in
			if case let .move(uid, _) = event, uid == heliUID { return true }
			return false
		}
		// If a move event is emitted at all, its path must end where the unit
		// actually stopped (so the sprite never overshoots the sim position).
		if case let .move(_, path)? = heliMove {
			#expect(
				sim.position[heliUID] == path[path.count - 1],
				"Sim position \(sim.position[heliUID]) must match emitted path end \(path[path.count - 1])"
			)
		}
		// The ambush still resolves as a surprise attack from the start tile.
		#expect(sim.position[heliUID] == XY(15, 10), "Ambushed mover should not have advanced")
		let attacked = events.contains { event in
			if case .fire = event { return true }
			return false
		}
		#expect(attacked, "First-step ambush should still trigger the surprise attack")
	}

	@Test func movesForOwnUnitNotIncludeStartTile() {
		let state = TacticalState(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			size: 32,
			seed: 0
		)

		let pick = state.sim.units.firstMapAlive { i, u in
			u.country == state.sim.country && u.canMove ? i.uid : nil
		}
		guard let uid = pick else {
			Issue.record("No movable own unit found")
			return
		}
		#expect(
			!state.sim.moves(for: uid)[state.sim.position[uid]],
			"Movable unit's own tile must not be reachable"
		)
	}

	// MARK: - Objectives

	/// Build a unitless 1v1 sim with a single city at `cityXY` owned by
	/// `controller`, for exercising `winner` in isolation. fin = axis (attacker),
	/// rus = soviet (defender).
	private static func objectiveSim(cityXY: XY, controller: Country) -> TacticalSim {
		var map = Map<32, Terrain>(size: 32, zero: .field)
		map[cityXY] = .city
		let players = [
			Player(country: .fin, type: .human, prestige: 0xF00),
			Player(country: .rus, type: .ai, prestige: 0xF00),
		]
		return TacticalSim(map: consume map, players: players, cities: [(cityXY, controller)], units: [])
	}

	@Test func captureDeadlineExpiresToDefender() {
		let target = XY(5, 5)
		var sim = Self.objectiveSim(cityXY: target, controller: .rus)
		sim.objective = .survive(.soviet, day: 3)

		sim.turn = 6
		#expect(sim.winner == .soviet)
	}

	@Test func annihilatingSurvivorBeforeDeadlineWinsForAttacker() {
		var sim = Self.objectiveSim(cityXY: XY(5, 5), controller: .rus)
		sim.objective = .survive(.soviet, day: 20)

		// Defender (rus = soviet) wiped out at day 3, well before the deadline.
		sim.turn = 4
		sim.players.modifyEach { _, p in if p.country == .rus { p.alive = false } }

		#expect(sim.winner == .axis, "Eliminating the survivor before its deadline wins")
	}

	@Test func ffaObjectiveResolvesOnLastTeamStanding() {
		var sim = Self.objectiveSim(cityXY: XY(5, 5), controller: .rus)
		#expect(sim.winner == nil, "Both teams alive → battle continues")

		sim.players.modifyEach { _, p in if p.country == .rus { p.alive = false } }
		#expect(sim.winner == .axis, "Last team standing wins")
	}
}
