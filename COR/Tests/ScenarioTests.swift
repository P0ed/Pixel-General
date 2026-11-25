import Testing
@testable import COR

struct ScenarioTests {
	private static var players: [Player] {
		[Player(country: .ger), Player(country: .usa, type: .ai),
		 Player(country: .rus, type: .ai), Player(country: .fin, type: .ai)]
	}

	@Test(arguments: [0, 7, 42, 1023], [0, 1, 2, 3])
	func generatedScenarios(seed: Int, density: Int) {
		let corners = Scenario.spawnOptions
		let players = Self.players
		let units = players.flatMap { [Unit].base($0.country) + .aux($0.country) }
		for (symmetry, continents) in [(false, false), (true, false), (false, true), (true, true)] {
			let mode = "seed \(seed), density \(density), symmetry \(symmetry), continents \(continents)"
			let scenario = Scenario(
				players: players, units: units, terrain: seed.isMultiple(of: 2) ? .forest : .field,
				spawns: .init { corners[$0] }, cityLevel: density, fortLevel: 1, seed: seed,
				symmetry: symmetry, continents: continents
			)
			let sim = scenario.makeSim()
			let map = clone(sim.map)
			#expect(map.indices.count { map[$0].isSettlement } == [20, 32, 48, 64][density], Comment(rawValue: mode))
			#expect(map.indices.contains { map[$0] == .fort }, Comment(rawValue: mode))

			let homes = Dictionary(uniqueKeysWithValues: players.indices.map { i in
				(players[i].country, Scenario.inCorner(corners[i], tile: Scenario.quarterCity))
			})
			for (i, player) in players.enumerated() {
				let city = homes[player.country]!
				let airfield = Scenario.inCorner(corners[i], tile: Scenario.quarterAirfield)
				#expect(map[city] == .city && sim.control[city] == player.country)
				#expect(city.manhattanDistance(to: airfield) == 1)
				#expect(map[airfield] == .airfield && sim.control[airfield] == player.country)
				let fleet = sim.units.compactMapAlive { _, unit in
					unit.country == player.country && unit.type.isNaval ? unit : nil
				}
				#expect(fleet.count == (continents ? 5 : 0))
				#expect(fleet.allSatisfy { $0[.aux] })
			}
			let misplaced = sim.units.compactMapAlive { i, unit -> XY? in
				let xy = sim.position[i]
				let home = homes[unit.country]!
				guard map.contains(xy), sim.unitsMap[xy] == i.uid else { return xy }
				if unit.type.isNaval {
					let adjacentShip = xy.n4.contains { sim[$0]?.type.isNaval == true }
					return map[xy].isSea && !adjacentShip && xy.manhattanDistance(to: home) <= 24 ? nil : xy
				}
				let nearHome = home.s49.contains { $0 == xy }
				return nearHome && (unit.isAir ? !map[xy].isNoFlyZone : !map[xy].isWater) ? nil : xy
			}
			#expect(misplaced.isEmpty, Comment(rawValue: mode))

			if symmetry {
				let reflectedX = isReflected(map, acrossX: true)
				let reflectedY = isReflected(map, acrossX: false)
				#expect(reflectedX && reflectedY, Comment(rawValue: mode))
				if !continents {
					#expect((0..<64).contains { map[XY(31, $0)].isRoad && map[XY(32, $0)].isRoad })
					#expect((0..<64).contains { map[XY($0, 31)].isRoad && map[XY($0, 32)].isRoad })
				}
			}
			if continents {
				let sea = Set(map.indices.filter { map[$0].isSea })
				let land = Set(map.indices.filter { !map[$0].isSea })
				let landmasses = components(of: land)
				#expect(landmasses.count == 4 && landmasses.allSatisfy { $0.count >= 400 }, Comment(rawValue: mode))
				#expect(components(of: sea).count == 1, Comment(rawValue: mode))
				#expect(land.allSatisfy { !(30...33).contains($0.x) && !(30...33).contains($0.y) })
				if !symmetry {
					#expect(sea.contains { !sea.contains(XY(63 - $0.x, $0.y)) })
					#expect(sea.contains { !sea.contains(XY($0.x, 63 - $0.y)) })
				}
			} else {
				#expect(!map.indices.contains { map[$0].isSea })
			}
			#expect(map.indices.allSatisfy { xy in
				switch map[xy] {
				case .bridgeWE: map[XY(xy.x - 1, xy.y)].hasRoad && map[XY(xy.x + 1, xy.y)].hasRoad
				case .bridgeSN: map[XY(xy.x, xy.y - 1)].hasRoad && map[XY(xy.x, xy.y + 1)].hasRoad
				default: true
				}
			}, Comment(rawValue: mode))
		}
	}

	@Test func explicitSpawnsAreReservedBeforeRandomSeats() {
		let corners = Scenario.spawnOptions
		let scenario = Scenario(
			players: Self.players, units: [], spawns: [nil, corners[0], corners[0], corners[3]], seed: 42
		)
		let spawns = scenario.resolvedSpawnPoints
		#expect(spawns == scenario.resolvedSpawnPoints)
		#expect(Set(spawns) == Set(Array(corners)))
		#expect(spawns[1] == corners[0])
		#expect(spawns[3] == corners[3])

		var observed = Set<XY>()
		for seed in 0..<16 {
			var other = scenario
			other.seed = seed
			observed.insert(other.resolvedSpawnPoints[0])
		}
		#expect(observed == [corners[1], corners[2]])
	}

	@Test(arguments: [2, 4])
	func threeActiveSeatsClearSymmetry(previousCount: Int) {
		var scenario = Scenario(players: Self.players, units: [], symmetry: true)
		if previousCount == 2 {
			scenario.players = Self.players.enumerated().map { index, player in
				modifying(player) { $0.alive = index < 2 }
			}
			scenario.symmetry = true
		}
		#expect(scenario.symmetry && scenario.symmetryAvailable)
		let corner = Scenario.spawnOptions[0]
		if previousCount == 4 {
			scenario.spawns[3] = corner
			#expect(!scenario.availableSpawns(for: 0).contains(corner))
		}
		let changedSeat = previousCount == 2 ? 2 : 3
		scenario.players[changedSeat].alive.toggle()
		#expect(!scenario.symmetry && !scenario.symmetryAvailable)
		scenario.symmetry = true
		#expect(!scenario.symmetry)
		if previousCount == 4 {
			#expect(scenario.availableSpawns(for: 0).contains(corner))
			#expect(scenario.spawns[3] == nil)
		}
		scenario.players[changedSeat].alive.toggle()
		#expect(!scenario.symmetry && scenario.symmetryAvailable)
		scenario.symmetry = true
		#expect(scenario.symmetry)
	}

	@Test(arguments: [false, true])
	func citiesAcrossTheOceanCountTowardQuotas(symmetry: Bool) {
		let corners = Scenario.spawnOptions
		let players = [Player(country: .ger), Player(country: .rus)]
		let scenario = Scenario(
			players: players, units: [], spawns: [corners[2], corners[3], nil, nil],
			cityLevel: 3, seed: 19, objective: .survive(.soviet, day: 30), symmetry: symmetry, continents: true
		)
		let sim = scenario.makeSim()
		let footprints = sim.map.cityFootprints
		var counts: [Country: Int] = [:]
		for city in footprints {
			let owner = sim.control[city[0]]
			#expect(city.allSatisfy { sim.control[$0] == owner })
			counts[owner, default: 0] += city.count
		}
		#expect(footprints.contains { $0[0].y > 33 })
		#expect(Set(counts.keys) == [.ger, .rus])
		let total = counts.values.reduce(0, +)
		#expect(abs(counts[.ger, default: 0] - total / 3) <= 2)
	}

	@Test(arguments: [false, true])
	func programmaticThreeSeatScenarioIgnoresSymmetry(continents: Bool) {
		var players = Self.players
		players[1].alive = false
		let scenario = Scenario(players: players, units: [], seed: 7, symmetry: true, continents: continents)
		let sim = scenario.makeSim()
		#expect(!scenario.symmetry)
		#expect(sim.players.count == 3)
		let reflectedX = isReflected(sim.map, acrossX: true)
		let reflectedY = isReflected(sim.map, acrossX: false)
		#expect(!reflectedX && !reflectedY)
		#expect(sim.map.indices.contains { sim.map[$0].isSea } == continents)
	}

	@Test func defenseFortsUseDefendingCitiesAfterSymmetricGeneration() {
		let objective = Objective.survive(.axis, day: 30)
		let scenario = Scenario(players: Self.players, units: [], fortLevel: 2, seed: 42, objective: objective, symmetry: true)
		let sim = scenario.makeSim()
		let base = Map<64, Terrain>(scenario: scenario)
		let forts = sim.map.indices.filter { sim.map[$0] == .fort }
		#expect(!forts.isEmpty)
		#expect(forts.allSatisfy { fort in
			sim.map.indices.contains { city in
				sim.map[city] == .city && sim.control[city].team == .axis && city.r12.contains { $0 == fort }
			}
		})
		#expect(sim.map.indices.allSatisfy { sim.map[$0] == .fort || sim.map[$0] == base[$0] })
		#expect(sim.objective == objective)
	}

	private func components(of tiles: Set<XY>) -> [Set<XY>] {
		var remaining = tiles
		var result: [Set<XY>] = []
		while let first = remaining.first {
			var stack = [first]
			var component: Set<XY> = [first]
			remaining.remove(first)
			while let xy = stack.popLast() {
				for neighbor in xy.n4 where remaining.remove(neighbor) != nil {
					stack.append(neighbor)
					component.insert(neighbor)
				}
			}
			result.append(component)
		}
		return result
	}

	private func isReflected(_ map: borrowing Map<64, Terrain>, acrossX: Bool) -> Bool {
		map.indices.allSatisfy { xy in
			let mirror = acrossX ? XY(63 - xy.x, xy.y) : XY(xy.x, 63 - xy.y)
			let expected: Terrain = switch (map[xy], acrossX) {
			case (.roadNE, true), (.roadSW, false): .roadNW
			case (.roadNW, true), (.roadSE, false): .roadNE
			case (.roadSE, true), (.roadNW, false): .roadSW
			case (.roadSW, true), (.roadNE, false): .roadSE
			case (.roadTE, true): .roadTW
			case (.roadTW, true): .roadTE
			case (.roadTN, false): .roadTS
			case (.roadTS, false): .roadTN
			default: map[xy]
			}
			return map[mirror] == expected
		}
	}
}
