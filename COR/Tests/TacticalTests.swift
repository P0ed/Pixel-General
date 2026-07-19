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
		let sim = TacticalSim(
			players: players,
			units: units,
			seed: 0
		)

		#expect(sim.map.size == 32)
		#expect(sim.players.count == 4)
		#expect(sim.units.count > 0, "No units placed")
		var cityCount = 0
		for xy in sim.map.indices where sim.map[xy] == .city { cityCount += 1 }
		#expect(cityCount > 0, "No cities placed")
		#expect(sim.turn == 0)

		// Every alive unit must occupy a unique tile and the unitsMap must
		// agree with `position`. Collect violations into local arrays so
		// `#expect` doesn't have to capture `state` (which contains a
		// noncopyable `Map`).
		var seen: Set<XY> = []
		var outOfMapPositions: [XY] = []
		var collisions: [XY] = []
		var unitsMapMismatches: [XY] = []
		sim.units.forEachAlive { i, u in
			let p = sim.position[i]
			if !sim.map.contains(p) { outOfMapPositions.append(p) }
			if !seen.insert(p).inserted { collisions.append(p) }
			if sim.unitsMap[p] != i.uid { unitsMapMismatches.append(p) }
		}
		#expect(outOfMapPositions.isEmpty, "Out-of-map unit positions: \(outOfMapPositions)")
		#expect(collisions.isEmpty, "Tile collisions: \(collisions)")
		#expect(unitsMapMismatches.isEmpty, "unitsMap mismatches at: \(unitsMapMismatches)")

		// Every city is controlled by one of the players (or default for the
		// degenerate empty-map case).
		let playerCountries = Set(players.map { $0.country })
		var cityBadCountry: [Country] = []
		for xy in sim.map.indices where sim.map[xy] == .city {
			let c = sim.control[xy]
			if !playerCountries.contains(c), c != .swe {
				cityBadCountry.append(c)
			}
		}
		#expect(cityBadCountry.isEmpty, "Cities with unexpected country: \(cityBadCountry)")
	}

	@Test func scenarioBuildsFromTerrainNeighborhood() {
		var terrain = [9 of Terrain](repeating: .field)
		terrain[2] = .sea
		let objective = Objective.survive(.soviet, day: 12)
		let scenario = Scenario(
			players: [
				Player(country: .fin, type: .human),
				Player(country: .rus, type: .ai),
			],
			units: [],
			terrain: terrain,
			fortLevel: 2,
			seed: 9,
			objective: objective
		)
		let sim = scenario.makeSim()

		var seaTiles = 0
		for xy in sim.map.indices where sim.map[xy].isSea { seaTiles += 1 }
		#expect(seaTiles > 0)
		#expect(sim.objective == objective)
		#expect(sim.players.count == 2)
	}

	@Test func spawnsClusterSettlementsAndKeepDefenderWeight() {
		let players = [
			Player(country: .fin, type: .human),
			Player(country: .rus, type: .ai),
		]
		for seed in 0 ..< 8 {
			let spawns = [XY(0, 1), XY(2, 1)]
			let sim = Scenario(
				players: players,
				units: [],
				spawns: spawns,
				seed: seed * 11,
				objective: .survive(.soviet, day: 12)
			).makeSim()

			var counts = [0, 0]
			var nearestOwner = [Country.default, Country.default]
			var nearestDistance = [Int.max, Int.max]
			for xy in sim.map.indices where sim.map[xy] == .city {
				let owner = sim.control[xy]
				if let idx = players.firstIndex(where: { p in p.country == owner }) {
					counts[idx] += 1
				}
				for (i, spawn) in spawns.enumerated() {
					let d = xy.manhattanDistance(to: spawn.cellCenter(size: sim.map.size))
					if d < nearestDistance[i] {
						nearestDistance[i] = d
						nearestOwner[i] = owner
					}
				}
			}
			#expect(
				counts[0] > 0 && counts[1] > 0,
				"Seed \(seed * 11): a seat owns no city (\(counts))"
			)
			#expect(
				counts[1] > counts[0],
				"Seed \(seed * 11): defender weighting lost (\(counts))"
			)
			for i in players.indices {
				#expect(
					nearestOwner[i] == players[i].country,
					"Seed \(seed * 11): city nearest spawn \(i) belongs to \(nearestOwner[i])"
				)
			}
		}
	}

	@Test func scenarioAddsNavalAuxAtThreeSeaTiles() {
		let players = [
			Player(country: .fin, type: .human, baseLevel: 2),
			Player(country: .rus, type: .ai),
		]
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea

		let belowThreshold = Scenario(players: players, units: [], terrain: terrain)
		#expect(!belowThreshold.units.contains { $0.type.isNaval })

		terrain[2] = .sea
		let scenario = Scenario(players: players, units: [], terrain: terrain, seed: 7)
		for player in players {
			let fleet = scenario.units.filter { $0.country == player.country }
			#expect(fleet.count(where: { $0.model == .cruiser }) == 1)
			#expect(fleet.count(where: { $0.model == .destroyer }) == 2)
			#expect(fleet.count(where: { $0.model == .cargo }) == 2)
			#expect(fleet.allSatisfy { $0[.aux] })
		}
		#expect(scenario.units.first(where: { $0.country == .fin })?.lvl == 2)

		let sim = scenario.makeSim()
		var misplaced: [XY] = []
		sim.units.forEachAlive { i, u in
			if u.type.isNaval, !sim.map[sim.position[i]].isSea {
				misplaced.append(sim.position[i])
			}
		}
		#expect(misplaced.isEmpty, "Ships deployed off sea at: \(misplaced)")
	}

	@Test func navalAuxKeepsFourFullRostersWithinUnitCapacity() {
		let countries: [Country] = [.swe, .den, .ned, .nor]
		let players = countries.map { Player(country: $0, type: .ai) }
		let units = countries.flatMap { [Unit].base($0) + .aux($0) }
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea
		terrain[2] = .sea

		let scenario = Scenario(players: players, units: units, terrain: terrain)
		#expect(scenario.units.count == 128)
		#expect(scenario.units.count(where: { $0.model == .cruiser }) == players.count)
		#expect(scenario.units.count(where: { $0.model == .destroyer }) == players.count * 2)
		#expect(scenario.units.count(where: { $0.model == .cargo }) == players.count * 2)
		for country in countries {
			let aux = scenario.units.count(where: { $0.country == country && $0[.aux] })
			#expect(aux == 16, "\(country) has \(aux) aux units")
		}
	}

	@Test func navalDeploymentSeparatesShipsAndTeamsAcrossSeeds() {
		let players = [
			Player(country: .fin, type: .human),
			Player(country: .rus, type: .ai),
			Player(country: .usa, type: .ai),
			Player(country: .swe, type: .ai),
		]
		let teams = Set(players.map { $0.country.team })
		for seed in 0 ..< 32 {
			let terrain = Scenario.cornerTerrain(seaLevel: 2, seed: seed)
			let sim = Scenario(players: players, units: [], terrain: terrain, seed: seed).makeSim()
			var cellsByTeam: [Team: Set<Int>] = [:]
			var adjacent: [(XY, XY)] = []

			sim.units.forEachAlive { i, unit in
				guard unit.type.isNaval else { return }
				let xy = sim.position[i]
				let column = min(2, xy.x * 3 / sim.map.size)
				let rowFromSouth = min(2, xy.y * 3 / sim.map.size)
				cellsByTeam[unit.country.team, default: []].insert((2 - rowFromSouth) * 3 + column)
				let neighbors = xy.n4
				for j in neighbors.indices {
					let p = neighbors[j]
					guard sim.map.contains(p), let other = sim[p], other.type.isNaval else { continue }
					adjacent.append((xy, p))
				}
			}

			#expect(adjacent.isEmpty, "Adjacent ships for seed \(seed): \(adjacent)")
			#expect(cellsByTeam.count == teams.count)
			#expect(cellsByTeam.values.allSatisfy { $0.count == 1 })
			let occupiedCells = Set(cellsByTeam.values.compactMap { $0.first })
			#expect(occupiedCells.count == teams.count)
			#expect(occupiedCells.allSatisfy { terrain[$0].isSea })
		}
	}

	@Test func navalDeploymentChoosesSeaCellsNearTeamCenterOfMass() {
		let players = [
			Player(country: .fin, type: .human),
			Player(country: .rus, type: .ai),
			Player(country: .usa, type: .ai),
			Player(country: .swe, type: .ai),
		]
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[2] = .sea
		terrain[6] = .sea
		terrain[8] = .sea
		let centers = TacticalSim.navalCenters(
			players: players,
			terrain: terrain,
			cities: [
				(XY(3, 3), .fin),
				(XY(7, 3), .swe),
				(XY(28, 28), .rus),
				(XY(28, 3), .usa),
			]
		)

		#expect(centers[.axis] == XY(5, 5))
		#expect(centers[.soviet] == XY(26, 26))
		#expect(centers[.allies] == XY(26, 5))
	}

	@Test func seaIsImpassableOnlyToLandUnits() {
		var infantry = Unit(model: .regular, country: .fin)
		infantry.reset()
		var fighter = Unit(model: .f16, country: .fin)
		fighter.reset()

		#expect(Terrain.sea.moveCost(infantry) == 0x10)
		#expect(Terrain.sea.moveCost(fighter) == 1)
		#expect(Terrain.river.moveCost(infantry) < 0x10, "River crossing must remain possible")
	}

	@Test func auxDeploysAtStartAndLeavesTheShop() {
		let players = Self.players()
		let sim = TacticalSim(
			players: players,
			units: players.flatMap { Array<Unit>.small($0.country) + .aux($0.country) },
			seed: 0
		)

		// Every seat fields its full default aux template, on the map and
		// ready to act on day 1, at no prestige cost.
		var deployed = [Int](repeating: 0, count: players.count)
		var unplaced = 0
		var notReady = 0
		sim.units.forEachAlive { i, u in
			guard u[.aux] else { return }
			if sim.offMap(unit: i.uid) { unplaced += 1 }
			if u.mp != u.maxMP || u.ap != u.maxAP { notReady += 1 }
			if let p = players.firstIndex(where: { $0.country == u.country }) {
				deployed[p] += 1
			}
		}
		#expect(unplaced == 0, "aux units left undeployed")
		#expect(notReady == 0, "aux units cannot act on day 1")
		for (i, p) in players.enumerated() {
			let expected = [COR.Unit].aux(p.country).count
			#expect(deployed[i] == expected, "seat \(i) fields \(deployed[i]) of \(expected) aux")
		}
		#expect(sim.players[0].prestige == 0xF00, "predeploy charged prestige")

		// The shop sells only the core catalogue.
		var auxRows = 0
		for xy in sim.map.indices {
			for u in sim.shopUnits(at: xy) where u[.aux] { auxRows += 1 }
		}
		#expect(auxRows == 0, "shop still sells aux units")
	}

	@Test func aiCanRunAndEndTurnWithoutCrash() {
		// Run several end-of-turn cycles on a state with all-AI players,
		// driving each turn via `runAI` until either the turn changes or we
		// exceed an iteration budget. We're not asserting the game ends; only
		// that the loop completes without a crash and that the turn counter
		// advances at least once.

		var ai = AI.Plan()

		var sim = TacticalSim(
			players: TacticalTests.players(types: [.ai, .ai, .ai, .ai]),
			units: .small(.swe) + .small(.usa) + .small(.rus) + .small(.pak),
			seed: 0
		)

		let initialTurn = sim.turn
		var iterations = 0
		let maxIterations = 1024

		while iterations < maxIterations {
			let action = sim.run(ai: &ai)
			_ = sim.reduce(action)
			iterations += 1
			if action == .end {
				if sim.turn > initialTurn + 4 {
					break
				}
			}
		}

		#expect(sim.turn > initialTurn, "AI never advanced the turn counter")
		#expect(iterations < maxIterations, "AI loop hit iteration cap")
	}

	@Test func endTurnIncrementsTurnCounter() {
		var sim = TacticalSim(
			players: Self.players(types: [.ai, .ai, .ai, .ai]),
			units: Array<Unit>.small(.swe),
			seed: 0
		)
		let before = sim.turn
		_ = sim.reduce(.end)
		#expect(sim.turn == before + 1, "End-of-turn must advance the turn counter")
	}

	@Test func helicopterEmbarkThenMoveKeepsPositionInSync() {
		// Repro: a 2-MP transport helicopter moves toward an elite infantry,
		// embarks it, then moves again. The sim position after the second move
		// must match the last tile of the emitted move event (what the sprite
		// animates to).
		let map = Map<32, Terrain>(zero: .field)
		let players = [Player(country: .usa, type: .human, prestige: 0xF00)]
		var heli = Unit(model: .mh6, country: .usa)
		heli.reset()
		var inf = Unit(model: .delta, country: .usa)
		inf.reset()

		var sim = TacticalSim(map: map, players: players, cities: [], units: [heli, inf])

		let heliUID = sim.units.firstMapAlive { i, u in u.type == .heli ? i.uid : nil }!
		let infUID = sim.units.firstMapAlive { i, u in u.type == .inf ? i.uid : nil }!

		// Lay the two units out on open ground with full vision.
		sim.place(heliUID, at: XY(15, 10))
		sim.place(infUID, at: XY(18, 10))
		sim.vision.modifyEach { v in v = .full }

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

	@Test func interruptedMovePathMatchesStoppedPosition() {
		// A move ambushed by a hidden enemy on the *first* step must not emit a
		// move event whose path runs past where the unit actually stops. The
		// sprite animates the event's path; the sim stores `pos`. They must agree.
		let map = Map<32, Terrain>(zero: .field)
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
		sim.place(heliUID, at: XY(15, 10))
		sim.place(enemyUID, at: XY(16, 10))
		// The mover can't see the enemy, so it walks into the ambush tile.
		sim.vision.modifyEach { v in v = .empty }

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
		let sim = TacticalSim(
			players: Self.players(),
			units: Array<Unit>.small(.swe),
			seed: 0
		)

		let pick = sim.units.firstMapAlive { i, u in
			u.country == sim.country && u.canMove ? i.uid : nil
		}
		guard let uid = pick else {
			Issue.record("No movable own unit found")
			return
		}
		#expect(
			!sim.moves(for: uid)[sim.position[uid]],
			"Movable unit's own tile must not be reachable"
		)
	}

	// MARK: - Objectives

	@Test func generatedBattlePreservesObjective() {
		let objective = Objective.survive(.axis, day: 32)
		let sim = TacticalSim(
			players: [
				Player(country: .ger, type: .ai),
				Player(country: .usa, type: .ai),
			],
			units: .base(.ger) + .base(.usa),
			seed: 3,
			objective: objective,
			forts: 1
		)
		#expect(sim.objective == objective)
	}

	/// Build a unitless 1v1 sim with a single city at `cityXY` owned by
	/// `controller`, for exercising `winner` in isolation. fin = axis (attacker),
	/// rus = soviet (defender).
	private static func objectiveSim(cityXY: XY, controller: Country) -> TacticalSim {
		var map = Map<32, Terrain>(zero: .field)
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

	@Test func annihilatingAttackerBeforeDeadlineWinsForSurvivor() {
		var sim = Self.objectiveSim(cityXY: XY(5, 5), controller: .rus)
		sim.objective = .survive(.soviet, day: 20)
		sim.players.modifyEach { _, p in if p.country == .fin { p.alive = false } }

		#expect(sim.winner == .soviet, "Last team standing wins before the survival deadline")
	}

	@Test func ffaObjectiveResolvesOnLastTeamStanding() {
		var sim = Self.objectiveSim(cityXY: XY(5, 5), controller: .rus)
		#expect(sim.winner == nil, "Both teams alive → battle continues")

		sim.players.modifyEach { _, p in if p.country == .rus { p.alive = false } }
		#expect(sim.winner == .axis, "Last team standing wins")
	}

	// MARK: Supply penalties

	/// Two-city field sim: swe (axis) owns (0, 0), rus (soviet) owns (7, 7),
	/// and `control` splits along their diagonal.
	private static func supplySim() -> TacticalSim {
		var map = Map<32, Terrain>(zero: .field)
		map[XY(0, 0)] = .city
		map[XY(7, 7)] = .city
		let players = [
			Player(country: .swe, type: .human, prestige: 0xF00),
			Player(country: .rus, type: .ai, prestige: 0xF00),
		]
		return TacticalSim(
			map: consume map,
			players: players,
			cities: [(XY(0, 0), .swe), (XY(7, 7), .rus)],
			units: []
		)
	}

	private static func infantry(ammo: UInt8 = 0, hp: UInt8 = 1) -> Unit {
		var u = Unit(model: .regular, country: .swe)
		u.reset()
		u.ammo = ammo
		u.hp = hp
		return u
	}

	@Test func resupplyOnOpenFriendlyGroundIsUnpenalised() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		let uid = sim.spawn(Self.infantry(), at: XY(2, 2))
		sim.resupply(unit: uid, into: &events)
		#expect(sim.units[uid].ammo == 2)
		#expect(sim.units[uid].hp == 1 + 3)
	}

	@Test func roughTerrainPenalisesResupply() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		sim.map[XY(4, 1)] = .forest
		let forest = sim.spawn(Self.infantry(), at: XY(4, 1))
		sim.resupply(unit: forest, into: &events)
		#expect(sim.units[forest].ammo == 2 - 1)
		#expect(sim.units[forest].hp == 1 + 3 - 1)

		sim.map[XY(1, 4)] = .mountain
		let mountain = sim.spawn(Self.infantry(), at: XY(1, 4))
		sim.resupply(unit: mountain, into: &events)
		#expect(sim.units[mountain].ammo == 0)
		#expect(sim.units[mountain].hp == 1 + 3 - 2)
	}

	@Test func enemyControlledTilePenalisesResupply() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		// (5, 5) is closer to the rus city — hostile ground for swe.
		let uid = sim.spawn(Self.infantry(), at: XY(5, 5))
		sim.resupply(unit: uid, into: &events)
		#expect(sim.units[uid].ammo == 2 - 1)
		#expect(sim.units[uid].hp == 1 + 3 - 1)
	}

	@Test func supplyTruckOffsetsRoughTerrain() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		sim.map[XY(1, 4)] = .mountain
		var truck = Unit(model: .truck, country: .swe)
		truck.reset()
		sim.spawn(truck, at: XY(1, 5))
		let uid = sim.spawn(Self.infantry(), at: XY(1, 4))
		sim.resupply(unit: uid, into: &events)
		#expect(sim.units[uid].ammo == 2 + 2 - 2)
		#expect(sim.units[uid].hp == 1 + 3 + 2 - 2)
	}

	@Test func adjacentEnemyPenalisesResupply() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		var enemy = Unit(model: .regular, country: .rus)
		enemy.reset()
		sim.spawn(enemy, at: XY(3, 2))
		let uid = sim.spawn(Self.infantry(), at: XY(2, 2))
		sim.resupply(unit: uid, into: &events)
		#expect(sim.units[uid].ammo == 0, "Adjacent enemy costs −2")
		#expect(sim.units[uid].hp == 1 + 3 - 2)
	}

	@Test func endOfTurnTrickleNeedsUncontestedSource() {
		var sim = Self.supplySim()
		var events: [TacticalEvent] = []

		// Spend `mp` so only the end-of-turn trickle applies, not the
		// untouched-unit restock.
		var moved = Self.infantry()
		moved.mp = 0

		var truck = Unit(model: .truck, country: .swe)
		truck.reset()
		sim.spawn(truck, at: XY(2, 3))
		let field = sim.spawn(moved, at: XY(2, 2))
		sim.resupply(unit: field, endOfTurn: true, into: &events)
		#expect(sim.units[field].ammo == 1, "Truck-fed trickle on open ground")

		let lone = sim.spawn(moved, at: XY(4, 1))
		sim.resupply(unit: lone, endOfTurn: true, into: &events)
		#expect(sim.units[lone].ammo == 0, "No source, no trickle")

		var truck2 = Unit(model: .truck, country: .swe)
		truck2.reset()
		sim.spawn(truck2, at: XY(5, 2))
		var enemy = Unit(model: .regular, country: .rus)
		enemy.reset()
		sim.spawn(enemy, at: XY(6, 1))
		let contested = sim.spawn(moved, at: XY(5, 1))
		sim.resupply(unit: contested, endOfTurn: true, into: &events)
		#expect(sim.units[contested].ammo == 0, "Adjacent enemy blocks the trickle")
	}

	@Test func supplyLevelWeighsSourcesAndPenalties() {
		var sim = Self.supplySim()
		sim.map[XY(1, 4)] = .mountain
		let sources = sim.supplySources(for: .swe)

		#expect(!sources.hostile[XY(2, 2)])
		#expect(sources.hostile[XY(5, 5)], "rus-controlled ground is hostile for swe")
		#expect(sources.level(at: XY(0, 1), terrain: .field) == 2, "In the owned city's c5")
		#expect(sources.level(at: XY(2, 2), terrain: .field) == 0)
		#expect(sources.level(at: XY(1, 4), terrain: .mountain) == -2)
		#expect(sources.level(at: XY(5, 5), terrain: .field) == -1)
	}

	@Test func foggedEnemiesDontMarkSupply() {
		var sim = Self.supplySim()
		var enemy = Unit(model: .regular, country: .rus)
		enemy.reset()
		sim.spawn(enemy, at: XY(6, 6))
		sim.spawn(Self.infantry(), at: XY(2, 2))

		let fogged = sim.supplySources(for: .swe)
		#expect(!fogged.enemies[XY(5, 6)], "Fogged enemy leaks into supply sources")

		sim.spawn(enemy, at: XY(3, 3))
		let spotted = sim.supplySources(for: .swe)
		#expect(spotted.enemies[XY(2, 2)], "Visible enemy marks its n8")
		#expect(spotted.level(at: XY(2, 2), terrain: .field) == -2)
	}

	// MARK: Air supply

	/// `supplySim` plus a swe airfield at (1, 1).
	private static func airfieldSim() -> TacticalSim {
		var sim = supplySim()
		sim.map[XY(1, 1)] = .airfield
		sim.settlements[XY(1, 1)] = true
		return sim
	}

	private static func fighter(ammo: UInt8 = 0, hp: UInt8 = 1) -> Unit {
		var u = Unit(model: .gripen, country: .swe)
		u.reset()
		u.ammo = ammo
		u.hp = hp
		return u
	}

	@Test func airResuppliesOnlyAtAirfields() {
		var sim = Self.airfieldSim()
		var events: [TacticalEvent] = []

		#expect(sim.supplySources(for: .swe).airfields[XY(1, 2)], "Airfield feeds its c5")

		let away = sim.spawn(Self.fighter(), at: XY(4, 4))
		sim.resupply(unit: away, into: &events)
		#expect(sim.units[away].ammo == 0, "No airfield in reach — no resupply")
		#expect(sim.units[away].hp == 1)

		let based = sim.spawn(Self.fighter(), at: XY(1, 2))
		sim.resupply(unit: based, into: &events)
		#expect(sim.units[based].ammo == 2, "Capped at maxAmmo")
		#expect(sim.units[based].hp == 1 + 2 + 3, "Airfield level 2 plus base heal 3")
	}

	@Test func airfieldsFeedGroundUnitsToo() {
		var sim = Self.airfieldSim()
		var events: [TacticalEvent] = []

		let uid = sim.spawn(Self.infantry(), at: XY(1, 2))
		sim.resupply(unit: uid, into: &events)
		#expect(sim.units[uid].ammo == 2 + 2, "Airfield feeds ground like a settlement")
		#expect(sim.units[uid].hp == 1 + 3 + 2)
	}

	@Test func airfieldSupplyWeighsTrucksAndEnemies() {
		var events: [TacticalEvent] = []

		var fed = Self.airfieldSim()
		var truck = Unit(model: .truck, country: .swe)
		truck.reset()
		fed.spawn(truck, at: XY(2, 2))
		let supplied = fed.spawn(Self.fighter(), at: XY(1, 2))
		fed.resupply(unit: supplied, into: &events)
		#expect(fed.units[supplied].hp == 1 + 4 + 3, "Truck adds +2 at the airfield")

		var contested = Self.airfieldSim()
		var enemy = Unit(model: .regular, country: .rus)
		enemy.reset()
		contested.spawn(enemy, at: XY(0, 2))
		let pinned = contested.spawn(Self.fighter(), at: XY(1, 2))
		contested.resupply(unit: pinned, into: &events)
		#expect(contested.units[pinned].hp == 1 + 3, "Adjacent enemy cancels the airfield bonus")
	}
}
