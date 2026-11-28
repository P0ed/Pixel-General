import Testing
@testable import COR

struct MapGenerationTests {

	@Test func startingUnitsDeployByCity() {
		let spawn = XY(20, 18)
		let home = [XY(20, 20), XY(21, 20)]
		let west = [XY(9, 18), XY(10, 18)]
		let east = XY(40, 20)
		let sea = XY(41, 20)
		var map = Map<64, Terrain>(zero: .field)
		let cities = (home + west + [east]).map { ($0, Country.ger) } + [(spawn, .usa)]
		for (xy, _) in cities { map[xy] = .city }
		map[sea] = .sea
		var core = Unit(model: .regular, country: .ger)
		core.reset()
		var ship = Unit(model: .destroyer, country: .ger).aux
		ship.reset()
		let sim = TACState(
			map: map, players: [Player(country: .ger)], cities: cities,
			units: [core.aux, core, core.aux, core, core.aux, ship, core], homes: [.ger: spawn]
		)
		#expect(sim.position[1] == home[0])
		#expect(sim.position[3] == home[1])
		#expect(sim.position[6].manhattanDistance(to: home[0]) == 1)
		#expect(sim.position[0] == west[1])
		#expect(sim.position[2] == east)
		#expect(sim.position[4] == west[0])
		#expect(sim.position[5] == sea)
	}

	@Test func coreHasPriorityInOnlyCity() {
		let home = XY(8, 8)
		var map = Map<64, Terrain>(zero: .field)
		map[home] = .city
		var core = Unit(model: .regular, country: .ger)
		core.reset()
		let sim = TACState(
			map: map, players: [Player(country: .ger)], cities: [(home, .ger)],
			units: [core.aux, core], homes: [.ger: home]
		)
		#expect(sim.position[1] == home)
		#expect(sim.position[0].manhattanDistance(to: home) == 1)
	}

	@Test(arguments: MapType.allCases, [false, true])
	func scenarioLandmasses(mapType: MapType, symmetry: Bool) {
		let players = [Country.ger, .usa, .isr, .rus].map { Player(country: $0) }
		let scenario = Scenario(players: players, units: [], cityLevel: 3, seed: 7, symmetry: symmetry, mapType: mapType)
		let map = Map<64, Terrain>(scenario: scenario)
		var visited = Set<XY>()
		var landmasses = 0
		for start in map.indices where !map[start].isSea && !visited.contains(start) {
			_ = landmass(on: map, from: start, into: &visited)
			landmasses += 1
		}
		let expected = switch mapType {
		case .land, .island: 1
		case .twoIslands: 2
		case .fourIslands: 4
		}
		#expect(landmasses == expected)
		#expect(map.indices.contains { map[$0].isSea } == (mapType != .land))
		if mapType != .land {
			#expect(map.indices.filter { map.edge(at: $0) != nil }.allSatisfy { map[$0].isSea })
		}
		let ports = map.indices.filter { map[$0] == .port }
		#expect(ports.count == (mapType == .land ? 0 : 4 * players.count))
		for port in ports {
			let neighbors = Array(port.n4)
			#expect(neighbors.count(where: { map[$0].isSea }) == 1)
			#expect(neighbors.count(where: { map.contains($0) && !map[$0].isWater }) == 3)
		}
	}

	@Test(arguments: [0, 7, 42], [0, 3])
	func settlementsCoverEachIsland(seed: Int, density: Int) {
		let players = [Country.ger, .usa, .isr, .rus].map { Player(country: $0) }
		let scenario = Scenario(players: players, units: [], cityLevel: density, seed: seed, symmetry: false, mapType: .fourIslands)
		let map = Map<64, Terrain>(scenario: scenario)
		var visited = Set<XY>()
		for corner in Scenario.spawnOptions {
			let home = Scenario.inCorner(corner, tile: Scenario.quarterCity)
			let island = landmass(on: map, from: home, into: &visited)
			let cities = island.filter { map[$0] == .city }
			let ports = island.filter { map[$0] == .port }
			let reach = island.map { xy in cities.map { xy.manhattanDistance(to: $0) }.min() ?? .max }.max()!
			#expect(reach <= (density == 0 ? 16 : 12))
			for (i, port) in ports.enumerated() {
				#expect(ports.dropFirst(i + 1).allSatisfy { port.manhattanDistance(to: $0) >= 10 })
			}
		}
	}

	@Test func terminatesAcrossManySeeds() {
		for seed in 0 ..< 16 {
			_ = Map<64, Terrain>(seed: seed)
		}
	}

	@Test func producesNonEmptyMapWithCitiesAndRivers() {
		var emptySeeds: [Int] = []
		var noCitySeeds: [Int] = []
		var noRiverSeeds: [Int] = []

		for seed in 0 ..< 8 {
			let map = Map<64, Terrain>(seed: seed * 7)
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

		#expect(emptySeeds.isEmpty, "Seeds that produced an all-`.none` map: \(emptySeeds)")
		#expect(noCitySeeds.isEmpty, "Seeds with no city: \(noCitySeeds)")
		#expect(noRiverSeeds.isEmpty, "Seeds with no river: \(noRiverSeeds)")
	}

	@Test(arguments: [Terrain.field, .forest])
	func spawnPointCitiesHaveAirfields(terrain: Terrain) {
		for seed in 0 ..< 8 {
			let spawns = (0 ..< 4).map { Scenario.spawnOptions[$0] }
			let map = Map<64, Terrain>(
				seed: seed * 13,
				terrain: .init(repeating: terrain),
				density: 0,
				spawns: spawns
			)
			let cities = cities(of: map)
			for spawn in spawns {
				let center = spawn.cellCenter(size: map.size)
				guard let city = cities.min(by: { a, b in
					(a.manhattanDistance(to: center), a.y, a.x)
						< (b.manhattanDistance(to: center), b.y, b.x)
				}) else {
					Issue.record("Seed \(seed * 13) generated no cities")
					continue
				}
				let hasAirfield = city.n4.contains { xy in
					map.contains(xy) && map[xy] == .airfield
				}
				#expect(
					hasAirfield,
					"Seed \(seed * 13): spawn \(spawn) city \(city) has no airfield"
				)
			}
		}
	}

	@Test(arguments: [0, 7, 42], [0, 1, 2, 3])
	func inlandSettlementTargets(seed: Int, density: Int) {
		let map = Map<64, Terrain>(seed: seed, density: density)
		let targets = [(24, 4, 4, 0), (32, 6, 6, 2), (48, 8, 8, 3), (64, 10, 10, 4)]
		let (settlements, airfields, pairs, triples) = targets[density]
		#expect(map.indices.count { map[$0].isSettlement } == settlements)
		#expect(map.indices.count { map[$0] == .airfield } == airfields)
		for xy in map.indices where map[xy] == .airfield {
			#expect(xy.n4.contains { map[$0].hasRoad })
		}

		let footprints = map.cityFootprints
		#expect(footprints.count { $0.count == 2 } == pairs)
		#expect(footprints.count { $0.count == 3 } == triples)
		#expect(footprints.allSatisfy { $0.count <= 3 })
		for i in footprints.indices {
			for j in footprints.indices.dropFirst(i + 1) {
				let spaced = footprints[i].allSatisfy { a in
					footprints[j].allSatisfy { b in a.stepDistance(to: b) >= map.size / 8 }
				}
				#expect(spaced)
			}
		}

		expectRoadNetworkConnectsCities(map)
	}

	@Test(arguments: [7, 19, 42])
	func clampsDensityOnCoastalAndMountainousMaps(seed: Int) {
		let coast: [16 of Terrain] = [
			.sea, .sea, .sea, .sea,
			.sea, .forest, .field, .field,
			.field, .field, .field, .field,
			.field, .field, .field, .field,
		]
		let high = Map<64, Terrain>(seed: seed, terrain: coast, density: 3)
		let above = Map<64, Terrain>(seed: seed, terrain: coast, density: 100)
		let inland = Map<64, Terrain>(seed: seed, terrain: .mountain, density: 3)
		#expect(high.indices.contains { high[$0].isSea })
		#expect(inland.indices.contains { inland[$0] == .mountain })
		#expect(high.indices.count { high[$0].isSettlement } <= 64)
		#expect(inland.indices.count { inland[$0].isSettlement } <= 64)
		let sameHigh = high.indices.allSatisfy { high[$0] == above[$0] }
		#expect(sameHigh)

		let low = Map<64, Terrain>(seed: seed, terrain: coast, density: 0)
		let below = Map<64, Terrain>(seed: seed, terrain: coast, density: -1)
		let sameLow = low.indices.allSatisfy { low[$0] == below[$0] }
		#expect(sameLow)
	}

	@Test func isDeterministicForSameSeed() {
		for seed in [0, 1, 7, 100, 999, 1023] {
			let a = Map<64, Terrain>(seed: seed)
			let b = Map<64, Terrain>(seed: seed)
			for xy in a.indices where a[xy] != b[xy] {
				Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
				break
			}
		}
	}

	@Test func usesConstantMapSize() {
		let map = Map<64, Terrain>(seed: 0)
		#expect(map.size == 64)
		#expect(map.count == 4096)
		var hasCity = false
		for xy in map.indices where map[xy] == .city { hasCity = true; break }
		#expect(hasCity, "Generated map has no city")
	}

	@Test func terrainBiasRaisesForestCoverage() {
		for seed in [1, 5, 42] {
			func forests(_ terrain: Terrain) -> Int {
				let map = Map<64, Terrain>(seed: seed, terrain: terrain)
				var result = 0
				for xy in map.indices {
					switch map[xy] {
					case .forest: result += 1
					default: break
					}
				}
				return result
			}
			#expect(forests(.field) < forests(.forest), "forest bias had no effect for seed \(seed)")
		}
	}

	@Test func terrainNeighborhoodShapesSeaWithHeightMap() {
		var terrain = [16 of Terrain](repeating: .field)
		terrain[0] = .sea // north-west terrain cell
		let a = Map<64, Terrain>(seed: 7, players: 2, terrain: terrain)
		let b = Map<64, Terrain>(seed: 19, players: 2, terrain: terrain)

		var aSea = Set<XY>()
		var bSea = Set<XY>()
		for xy in a.indices {
			if a[xy].isSea { aSea.insert(xy) }
			if b[xy].isSea { bSea.insert(xy) }
		}
		#expect(!aSea.isEmpty, "Sea neighborhood produced no water")
		#expect(aSea.count < a.count, "Sea neighborhood flooded the whole map")
		#expect(aSea != bSea, "Different height maps produced the same square shore")
		var landInsideNominalShore = 0
		var centerSea = 0
		var centerTiles = 0
		var peripheralSea = 0
		var peripheralTiles = 0
		let centerXY = XY(0, 3).cellCenter(size: a.size)
		for xy in a.indices {
			let nominalSea = xy.x < 16 && xy.y >= 48
			if !a[xy].isSea, nominalSea { landInsideNominalShore += 1 }
			let center = abs(xy.x - centerXY.x) <= 4 && abs(xy.y - centerXY.y) <= 4
			if center {
				centerTiles += 1
				if a[xy].isSea { centerSea += 1 }
			} else if nominalSea {
				peripheralTiles += 1
				if a[xy].isSea { peripheralSea += 1 }
			}
		}
		#expect(landInsideNominalShore >= 4, "High ground did not break up the terrain square")
		#expect(aSea.count <= a.count / 12, "Sea occupied too much of its terrain square")
		#expect(
			centerSea * peripheralTiles > peripheralSea * centerTiles,
			"Sea did not become less likely away from its terrain center"
		)
	}

	@Test func riversOnlyTouchSeaAtTerminalMouths() {
		var terrain = [16 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea
		terrain[4] = .sea
		var mouths = 0
		for seed in 0 ..< 24 {
			let map = Map<64, Terrain>(seed: seed, players: 4, terrain: terrain)
			for xy in map.indices where map[xy].isRiver || map[xy].isBridge {
				let touchesSea = xy.n8.contains { p in map[p].isSea }
				guard touchesSea else { continue }
				mouths += 1
				#expect(xy.n4.contains({ p in map[p].isSea }), "River mouth at \(xy) only meets sea diagonally for seed \(seed)")
				var riverNeighbors = [] as [XY]
				let neighbors = xy.n4
				for i in neighbors.indices {
					let p = neighbors[i]
					if map[p].isRiver || map[p].isBridge { riverNeighbors.append(p) }
				}
				#expect(riverNeighbors.count == 1, "River at \(xy) follows rather than terminates at the shore for seed \(seed)")
				if let inland = riverNeighbors.first {
					#expect(!inland.n8.contains({ p in map[p].isSea }), "River continues through the shore at \(xy) for seed \(seed)")
				}
			}
		}
		#expect(mouths > 0, "No generated river terminated at the sea")
	}

	@Test func citiesStayOffIslandsAndSmallIslandsAreRemoved() {
		var terrain = [16 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea
		terrain[4] = .sea
		for seed in 0 ..< 16 {
			let map = Map<64, Terrain>(seed: seed, players: 4, terrain: terrain)

			var visited = Set<XY>()
			let mainland = Set(landmass(on: map, from: XY(map.size / 2, map.size / 2), into: &visited))

			var islands = 0
			for start in map.indices where !map[start].isSea && !visited.contains(start) {
				islands += 1
				let island = landmass(on: map, from: start, into: &visited)
				#expect(island.count >= 6, "Small island of \(island.count) tiles survived for seed \(seed)")
				#expect(!island.contains(where: { xy in map[xy] == .city }), "City generated on an island for seed \(seed)")
			}
			#expect(islands <= 1, "Too many islands (\(islands)) survived for seed \(seed)")
			for xy in map.indices where map[xy] == .city {
				#expect(mainland.contains(xy), "City at \(xy) is not on the mainland for seed \(seed)")
			}
		}
	}

	@Test func roadsConnectAllCities() {
		// MST-based road building links every terrain-reachable city into
		// one network; on these seeds all cities share one landmass, so a
		// flood along road tiles from any city must reach every other.
		for seed in [0, 7, 21, 42, 5, 11] {
			let map = Map<64, Terrain>(seed: seed)
			expectRoadNetworkConnectsCities(map)
		}
	}

	private func landmass(on map: borrowing Map<64, Terrain>, from start: XY, into visited: inout Set<XY>) -> [XY] {
		var tiles = [start]
		var head = 0
		visited.insert(start)
		while head < tiles.count {
			let neighbors = tiles[head].n4
			head += 1
			for i in neighbors.indices {
				let p = neighbors[i]
				guard map.contains(p), !map[p].isSea, !visited.contains(p) else { continue }
				visited.insert(p)
				tiles.append(p)
			}
		}
		return tiles
	}

	private func expectRoadNetworkConnectsCities(_ map: borrowing Map<64, Terrain>) {
		let cities = cities(of: map)
		guard let first = cities.first else {
			Issue.record("No cities generated")
			return
		}
		var seen = Set([first])
		var stack = [first]
		while let xy = stack.popLast() {
			for p in xy.n4 where map.contains(p) && map[p].hasRoad && seen.insert(p).inserted {
				stack.append(p)
			}
		}
		for city in cities where !seen.contains(city) {
			Issue.record("City tile \(city) off the road network")
		}
	}

	@Test func roadsRouteAroundAirfields() {
		let start = XY(10, 10)
		let end = XY(12, 10)
		let airfield = XY(11, 10)
		let bypass = [XY(10, 11), XY(11, 11), XY(12, 11)]
		var map = Map<64, Terrain>(zero: .mountain)
		map[start] = .city
		map[end] = .city
		map[airfield] = .airfield
		for xy in bypass { map[xy] = .field }

		map.connectCities(cities: [start, end])
		map.shapeRoads()

		#expect(map[airfield] == .airfield)
		#expect(map[bypass[1]] == .roadWE)
		#expect(bypass.allSatisfy { map[$0].isRoad })
	}

	@Test func roadShapingCreatesJunctionsWithOrdinaryRoadRules() {
		let junctions: [(missingArm: Int?, terrain: Terrain)] = [
			(0, .roadTE), (1, .roadTN), (2, .roadTW), (3, .roadTS), (nil, .roadX),
		]
		let center = XY(32, 32)
		let neighbors = center.n4
		for (missingArm, expected) in junctions {
			var map = Map<64, Terrain>(zero: .field)
			map[center] = .roadWE
			for i in neighbors.indices where i != missingArm {
				map[neighbors[i]] = .roadWE
			}
			map.shapeRoads()

			let road = map[center]
			#expect(road == expected)
			#expect(road.isRoad && road.isBridgable)
			#expect(!road.isSettlement)
			#expect(road.moveCost(Unit(model: .f16, country: .usa)) == 1)
			#expect(road.income == 0)
			#expect(road.baseEntrenchment == 0)
			#expect(road.def(.inf) == Terrain.roadWE.def(.inf))
			#expect(road.closeCombat(.heavyTrack) == 0)
		}
	}

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors. Diagonal-only adjacency would mean the river
		// was disconnected.
		for seed in [3, 11, 23] {
			let map = Map<64, Terrain>(seed: seed)
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
	}

	@Test func defaultGenerationPlacesNoForts() {
		for seed in [0, 7, 42, 100] {
			let map = Map<64, Terrain>(seed: seed)
			for xy in map.indices where map[xy] == .fort {
				Issue.record("Fort at \(xy) for seed \(seed) before placeForts")
				break
			}
		}
	}

	@Test func fortsReplaceOnlyOpenTerrain() {
		// Rings only overwrite field/forest/hill, so every fort must sit
		// where open ground used to be, and every other tile must be
		// untouched — roads, rivers and settlements survive.
		for seed in [0, 7, 5] {
			let base = Map<64, Terrain>(seed: seed)
			var map = clone(base)
			map.placeForts(around: cities(of: base), level: 3)
			var forts = 0
			for xy in map.indices {
				if map[xy] == .fort {
					forts += 1
					switch base[xy] {
					case .field, .forest, .rough: break
					default: Issue.record("Fort replaced \(base[xy]) at \(xy) for seed \(seed)")
					}
				} else if map[xy] != base[xy] {
					Issue.record("Fort placement disturbed \(base[xy]) at \(xy) for seed \(seed)")
				}
			}
			#expect(forts > 0, "No forts for seed \(seed)")
		}
	}

	@Test func fortsRingCitiesAtChebyshevTwo() {
		// Every fort must lie on some city's ring: Chebyshev distance
		// exactly 2 with the four corners cut.
		for seed in [0, 7, 42] {
			var map = Map<64, Terrain>(seed: seed)
			let centers = cities(of: map)
			map.placeForts(around: centers, level: 3)
			for xy in map.indices where map[xy] == .fort {
				let onRing = centers.contains { c in
					let dx = abs(xy.x - c.x), dy = abs(xy.y - c.y)
					return max(dx, dy) == 2 && dx + dy < 4
				}
				#expect(onRing, "Fort at \(xy) off every city ring for seed \(seed)")
			}
		}
	}

	@Test func fortCountScalesWithLevelAndCaps() {
		for seed in [0, 7, 42] {
			func forts(_ level: Int) -> Int {
				var map = Map<64, Terrain>(seed: seed)
				let centers = cities(of: map)
				map.placeForts(around: centers, level: level)
				var count = 0
				for xy in map.indices where map[xy] == .fort { count += 1 }
				return count
			}
			#expect(forts(3) >= forts(1), "Level 3 placed fewer forts than level 1 for seed \(seed)")
			#expect(forts(3) <= 3 * 3 * 64 / 4, "Level 3 exceeded the fort cap for seed \(seed)")
		}
	}

	@Test func fortsSpreadAcrossAllCities() {
		// Round-robin placement: every city whose ring has open ground
		// must get at least one fort, even at the lowest level.
		for seed in [0, 7, 42] {
			let base = Map<64, Terrain>(seed: seed)
			var map = clone(base)
			let centers = cities(of: base)
			map.placeForts(around: centers, level: 1)
			for c in centers {
				let ring = c.r12
				var open = false
				var fort = false
				for i in ring.indices {
					switch base[ring[i]] {
					case .field, .forest, .rough: open = true
					default: break
					}
					if map[ring[i]] == .fort { fort = true }
				}
				if open, !fort {
					Issue.record("City at \(c) got no fort for seed \(seed)")
				}
			}
		}
	}

	@Test func fortPlacementIsDeterministic() {
		for seed in [0, 7, 999] {
			var a = Map<64, Terrain>(seed: seed)
			var b = Map<64, Terrain>(seed: seed)
			let centers = cities(of: a)
			a.placeForts(around: centers, level: 3)
			b.placeForts(around: centers, level: 3)
			for xy in a.indices where a[xy] != b[xy] {
				Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
				break
			}
		}
	}

	private func cities(of map: borrowing Map<64, Terrain>) -> [XY] {
		map.indices.compactMap { xy in map[xy] == .city ? xy : nil }
	}

	@Test func riversReachTheMapEdge() {
		// River mouths sit on map edges by construction, so every generated
		// map must have at least one river tile on its border.
		for seed in [3, 11, 23] {
			let map = Map<64, Terrain>(seed: seed)
			var touches = false
			for xy in map.indices where map[xy].isRiver && map.edge(at: xy) != nil {
				touches = true; break
			}
			#expect(touches, "No river touches the map edge for seed \(seed)")
		}
	}
}
