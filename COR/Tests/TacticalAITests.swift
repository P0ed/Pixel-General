import Testing
@testable import COR

struct TacticalAITests {

	private static func plannedSim(objective: Objective = .none) -> TacticalSim {
		var map = Map<64, Terrain>(zero: .field)
		map[XY(1, 1)] = .city
		map[XY(5, 1)] = .city
		map[XY(8, 8)] = .city
		let players = [
			Player(country: .ger, type: .ai, prestige: .poor),
			Player(country: .fin, type: .ai, prestige: .poor),
			Player(country: .usa, type: .ai, prestige: .poor),
		]
		var units = players.map { Unit(model: .regular, country: $0.country) }
		units.modifyEach { u in u.reset() }
		var sim = TacticalSim(
			map: consume map,
			players: players,
			cities: [(XY(1, 1), .ger), (XY(5, 1), .fin), (XY(8, 8), .usa)],
			units: units
		)
		sim.objective = objective
		sim.vision.modifyEach { v in v = .full }
		return sim
	}

	/// Open-field ger-vs-usa duel: cities placed and controlled as given,
	/// units reset and placed in order (UID = array index), full vision
	/// unless the test punches its own holes.
	private static func duelSim(
		cities: [(XY, Country)] = [(XY(0, 0), .ger), (XY(9, 9), .usa)],
		units: [COR.Unit],
		at positions: [XY],
		fullVision: Bool = true
	) -> TacticalSim {
		var map = Map<64, Terrain>(zero: .field)
		for (xy, _) in cities { map[xy] = .city }
		var units = units
		units.modifyEach { u in u.reset() }
		var sim = TacticalSim(
			map: consume map,
			players: [
				Player(country: .ger, type: .ai, prestige: .poor),
				Player(country: .usa, type: .ai, prestige: .poor),
			],
			cities: cities,
			units: units
		)
		for (i, xy) in positions.enumerated() { sim.place(i.uid, at: xy) }
		if fullVision { sim.vision.modifyEach { v in v = .full } }
		return sim
	}

	@Test func alliedSettlementsNeverBecomeHostileObjectives() {
		let sim = Self.plannedSim()
		var ai = AI.Plan()
		_ = sim.run(ai: &ai)

		let hasOwn = ai.ownSettlements.contains(XY(1, 1))
		let hasAlly = ai.alliedSettlements.contains(XY(5, 1))
		let hasEnemy = ai.enemySettlements.contains(XY(8, 8))
		let allyIsEnemy = ai.enemySettlements.contains(XY(5, 1))
		#expect(hasOwn)
		#expect(hasAlly)
		#expect(hasEnemy)
		#expect(!allyIsEnemy)
		#expect(ai.focusTarget != XY(5, 1))
	}

	@Test func survivalObjectiveSelectsDefenderAndAttackerStances() {
		let defender = Self.plannedSim(objective: .survive(.axis, day: 20))
		var defenderAI = AI.Plan()
		_ = defender.run(ai: &defenderAI)
		#expect(defenderAI.stance == .defendSurvival)

		let attacker = Self.plannedSim(objective: .survive(.allies, day: 20))
		var attackerAI = AI.Plan()
		_ = attacker.run(ai: &attackerAI)
		#expect(attackerAI.stance == .attackSurvival)
	}

	@Test func retreatAssignmentsUseCompatibleSupplyHavens() {
		var map = Map<64, Terrain>(zero: .field)
		map[XY(1, 1)] = .city
		map[XY(1, 4)] = .airfield
		map[XY(8, 8)] = .city
		let players = [
			Player(country: .ger, type: .ai, prestige: .poor),
			Player(country: .usa, type: .ai, prestige: .poor),
		]
		var ground = Unit(model: .regular, country: .ger)
		var air = Unit(model: .skeldar, country: .ger)
		ground.reset(); air.reset()
		ground.hp = 2; air.hp = 2
		var sim = TacticalSim(
			map: consume map,
			players: players,
			cities: [(XY(1, 1), .ger), (XY(1, 4), .ger), (XY(8, 8), .usa)],
			units: [ground, air]
		)
		let groundID = sim.units.firstMapAlive { i, u in !u.isAir ? i.uid : nil }!
		let airID = sim.units.firstMapAlive { i, u in u.isAir ? i.uid : nil }!
		sim.place(groundID, at: XY(4, 1))
		sim.place(airID, at: XY(4, 4))
		sim.vision.modifyEach { v in v = .full }

		var ai = AI.Plan()
		_ = sim.run(ai: &ai)
		#expect(ai.role[groundID.index] == .retreat)
		#expect(sim.map[ai.target[groundID.index]].isSettlement)
		#expect(ai.role[airID.index] == .retreat)
		#expect(sim.map[ai.target[airID.index]] == .airfield)
	}

	@Test func globalAttackSelectionIsNotBoundToFirstAttacker() {
		let sim = Self.duelSim(
			units: [
				Unit(model: .regular, country: .ger),	// weak
				Unit(model: .mars, country: .ger),		// strong
				Unit(model: .militia, country: .usa),	// target
			],
			at: [XY(4, 3), XY(3, 3), XY(5, 3)]
		)

		var ai = AI.Plan()
		guard case let .attack(source, destination) = sim.run(ai: &ai) else {
			Issue.record("heuristic did not take an available attack")
			return
		}
		#expect(source == 1.uid)
		#expect(destination == 2.uid)
	}

	@Test func attackSelectionFocusesWoundedTargets() {
		var sim = Self.duelSim(
			units: [
				Unit(model: .mars, country: .ger),
				Unit(model: .militia, country: .usa),	// full
				Unit(model: .militia, country: .usa),	// wounded
			],
			at: [XY(3, 3), XY(5, 3), XY(3, 5)]
		)
		sim.units[2.uid].hp = 2

		var ai = AI.Plan()
		guard case let .attack(_, target) = sim.run(ai: &ai) else {
			Issue.record("heuristic did not take an available attack")
			return
		}
		#expect(target == 2.uid)
	}

	@Test func attackSelectionAvoidsVisibleSupportFire() {
		let sim = Self.duelSim(
			units: [
				Unit(model: .f35, country: .ger),
				Unit(model: .militia, country: .usa),	// protected by the patriot
				Unit(model: .militia, country: .usa),	// safe to strike
				Unit(model: .patriot, country: .usa),
			],
			at: [XY(3, 3), XY(5, 3), XY(3, 5), XY(6, 3)]
		)

		var ai = AI.Plan()
		guard case let .attack(_, target) = sim.run(ai: &ai) else {
			Issue.record("aircraft did not take an available attack")
			return
		}
		#expect(target == 2.uid)
	}

	@Test func hiddenSupportDoesNotChangeHeuristicAction() {
		func make(_ includeSupport: Bool) -> TacticalSim {
			var units = [
				Unit(model: .f35, country: .ger),
				Unit(model: .militia, country: .usa),
			]
			var positions = [XY(3, 3), XY(5, 3)]
			if includeSupport {
				units.append(Unit(model: .patriot, country: .usa))
				positions.append(XY(6, 3))
			}
			var sim = Self.duelSim(units: units, at: positions, fullVision: false)
			sim.vision[0] = .empty
			sim.vision[0][XY(3, 3)] = true
			sim.vision[0][XY(5, 3)] = true
			return sim
		}

		let withoutHidden = make(false)
		let withHidden = make(true)
		var first = AI.Plan()
		var second = AI.Plan()
		let a = withoutHidden.run(ai: &first)
		let b = withHidden.run(ai: &second)
		#expect(a == b)
		#expect(a == .attack(0.uid, 1.uid))
	}

	@Test func aiSeeksAndHoldsCityTilesForCapture() {
		let airfield = XY(4, 0)
		let enemyCity = XY(5, 0)
		var map = Map<64, Terrain>(zero: .field)
		map[XY(0, 0)] = .city
		map[enemyCity] = .city
		map[airfield] = .airfield
		var sim = TacticalSim(
			map: map,
			players: [Player(country: .ger, prestige: 0), Player(country: .usa)],
			cities: [(XY(0, 0), .ger), (enemyCity, .usa)],
			units: []
		)
		var ground = Unit(model: .regular, country: .ger)
		ground.reset()
		let uid = sim.spawn(ground, at: airfield)

		var ai = AI.Plan()
		#expect(sim.run(ai: &ai) == .move(uid, enemyCity))
		let seesAirfield = ai.enemySettlements.contains(airfield)
		#expect(seesAirfield)
		#expect(ai.focusTarget == enemyCity)
		_ = sim.reduce(.move(uid, enemyCity))
		sim.units[uid].reset()
		#expect(sim.run(ai: &ai) == .end)
		_ = sim.reduce(.end)
		#expect(sim.control[enemyCity] == .ger)
	}

	@Test(arguments: MapType.allCases)
	func aiProcessesMaximumSettlementTiles(mapType: MapType) {
		let sim = Scenario(
			players: [Player(country: .ger, type: .ai)],
			units: [Unit(model: .regular, country: .ger)],
			cityLevel: 3,
			seed: 7,
			objective: .survive(.axis, day: 12), mapType: mapType
		).makeSim()
		var ai = AI.Plan()
		_ = sim.run(ai: &ai)
		#expect(ai.ownSettlements.count == (mapType == .land ? 64 : 68))
		let airfields = ai.ownSettlements.count { sim.map[$0] == .airfield }
		#expect(airfields == (mapType == .land ? 10 : 12))
		#expect(ai.focusTarget.map { sim.map[$0] } == .city)
	}

	@Test func rangedMoverSeeksPostMoveFiringPosition() {
		let sim = Self.duelSim(
			cities: [(XY(0, 1), .ger), (XY(9, 1), .usa)],
			units: [
				Unit(model: .mars, country: .ger),
				Unit(model: .militia, country: .usa),
			],
			at: [XY(1, 1), XY(7, 1)]
		)
		let range = Int(sim.units[0].rng) * 2 + 1
		#expect(sim.position[0].stepDistance(to: sim.position[1]) > range)

		var ai = AI.Plan()
		guard case let .move(source, destination) = sim.run(ai: &ai) else {
			Issue.record("mobile artillery did not seek a firing position")
			return
		}
		#expect(source == 0.uid)
		#expect(destination.stepDistance(to: sim.position[1]) <= range)
	}

	@Test func reusedRosterSlotReceivesFreshAssignment() {
		var sim = Self.plannedSim()
		var ai = AI.Plan()
		_ = sim.run(ai: &ai)
		let uid = sim.units.firstMapAlive { i, u in u.country == .ger ? i.uid : nil }!
		ai.role[uid.index] = .retreat

		sim.vacate(uid)
		sim.units[uid].hp = 0
		_ = sim.run(ai: &ai) // observe the slot leaving the roster
		var replacement = Unit(model: .m1A2, country: .ger)
		replacement.reset()
		let replacementID = sim.spawn(replacement, at: XY(2, 2))
		#expect(replacementID == uid)
		_ = sim.run(ai: &ai)

		let rosterContainsReplacement = ai.roster.contains(uid)
		#expect(rosterContainsReplacement)
		#expect(ai.role[uid.index] != .retreat)
		#expect(ai.country == .ger)
	}

	@Test func survivalHeuristicTurnsRemainBounded() {
		var sim = TacticalSim(
			players: [
				Player(country: .fin, type: .ai, prestige: .poor),
				Player(country: .isr, type: .ai, prestige: .poor),
			],
			units: .base(.fin),
			seed: 1,
			objective: .survive(.axis, day: 40),
			forts: 1
		)
		var ai = AI.Plan()
		var actions = 0
		var turnActions = 0
		var observedTurn = sim.turn
		var maximum = 0
		while actions < 20_000, sim.winner == nil, sim.day <= 128 {
			if sim.turn != observedTurn {
				observedTurn = sim.turn
				turnActions = 0
			}
			let action = sim.run(ai: &ai)
			_ = sim.reduce(action)
			turnActions += 1
			maximum = max(maximum, turnActions)
			actions += 1
		}
		#expect(maximum <= 257)
		#expect(sim.winner != nil)
		#expect(actions < 20_000)
	}
}
