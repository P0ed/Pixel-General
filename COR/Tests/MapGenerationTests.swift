import Testing
@testable import COR

struct MapGenerationTests {

	@Test func terminatesAcrossManySeeds() {
		for seed in 0 ..< 16 {
			_ = Map<32, Terrain>(seed: seed)
		}
	}

	@Test func producesNonEmptyMapWithCitiesAndRivers() {
		var emptySeeds: [Int] = []
		var noCitySeeds: [Int] = []
		var noRiverSeeds: [Int] = []

		for seed in 0 ..< 8 {
			let map = Map<32, Terrain>(seed: seed * 7)
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

	@Test func spawnPointCitiesHaveAirfields() {
		for seed in 0 ..< 8 {
			let spawns = Array(XY.one.n4)
			let map = Map<32, Terrain>(
				seed: seed * 13,
				terrain: .init(repeating: .field),
				spawns: spawns
			)
			let cities = cities(of: map)
			for spawn in spawns {
				let center = spawn.cellCenter(size: map.size)
				guard let city = cities.min(by: { a, b in
					(a.manhattanDistance(to: center), a.x, a.y)
						< (b.manhattanDistance(to: center), b.x, b.y)
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

	@Test func isDeterministicForSameSeed() {
		for seed in [0, 1, 7, 100, 999, 1023] {
			let a = Map<32, Terrain>(seed: seed)
			let b = Map<32, Terrain>(seed: seed)
			for xy in a.indices where a[xy] != b[xy] {
				Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
				break
			}
		}
	}

	@Test func usesConstantMapSize() {
		let map = Map<32, Terrain>(seed: 0)
		#expect(map.size == 32)
		#expect(map.count == 32 * 32)
		var hasCity = false
		for xy in map.indices where map[xy] == .city { hasCity = true; break }
		#expect(hasCity, "Generated map has no city")
	}

	@Test func terrainBiasRaisesHighground() {
		// A hill/mountain province must generate a battle map with more
		// highground than the plains baseline, and still place cities.
		for seed in [1, 5, 42] {
			func highground(_ terrain: Terrain) -> Int {
				let map = Map<32, Terrain>(seed: seed, terrain: terrain)
				var high = 0, cities = 0
				for xy in map.indices {
					if map[xy].isHighground { high += 1 }
					if map[xy] == .city { cities += 1 }
				}
				#expect(cities > 0, "no city on \(terrain) map for seed \(seed)")
				return high
			}
			let field = highground(.field)
			let hill = highground(.hill)
			let mountain = highground(.mountain)
			#expect(field < hill, "hill bias did not raise highground for seed \(seed)")
			#expect(hill < mountain, "mountain bias did not raise highground for seed \(seed)")
		}
	}

	@Test func terrainBiasRaisesForestCoverage() {
		for seed in [1, 5, 42] {
			func forests(_ terrain: Terrain) -> Int {
				let map = Map<32, Terrain>(seed: seed, terrain: terrain)
				var result = 0
				for xy in map.indices {
					switch map[xy] {
					case .forest, .forestHill: result += 1
					default: break
					}
				}
				return result
			}
			#expect(forests(.field) < forests(.forest), "forest bias had no effect for seed \(seed)")
			#expect(forests(.hill) < forests(.forestHill), "forest-hill bias had no effect for seed \(seed)")
		}
	}

	@Test func terrainNeighborhoodShapesSeaWithHeightMap() {
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea // north-west strategic tile
		let a = Map<32, Terrain>(seed: 7, players: 2, terrain: terrain)
		let b = Map<32, Terrain>(seed: 19, players: 2, terrain: terrain)

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
		for xy in a.indices {
			let nominalSea = xy.x < 11 && xy.y >= 21
			if !a[xy].isSea, nominalSea { landInsideNominalShore += 1 }
			let center = (3 ..< 8).contains(xy.x) && (24 ..< 29).contains(xy.y)
			if center {
				centerTiles += 1
				if a[xy].isSea { centerSea += 1 }
			} else if nominalSea {
				peripheralTiles += 1
				if a[xy].isSea { peripheralSea += 1 }
			}
		}
		#expect(landInsideNominalShore >= 4, "High ground did not break up the strategic square")
		#expect(aSea.count <= a.count / 12, "Sea occupied too much of its strategic square")
		#expect(
			centerSea * peripheralTiles > peripheralSea * centerTiles,
			"Sea did not become less likely away from its strategic center"
		)
	}

	@Test func scenarioSeaLevelsAreCumulativeAndSeededByCorner() {
		let validPairs: Set<Set<Int>> = [
			[2, 1], [0, 1], [6, 7], [8, 7],
		]
		let validCorners: Set<Set<Int>> = [
			[2, 1, 5], [0, 1, 3], [6, 7, 3], [8, 7, 5],
		]
		let validCoasts: Set<Set<Int>> = [
			[2, 1, 5, 0], [0, 1, 3, 2], [6, 7, 3, 8], [8, 7, 5, 2],
		]
		var observedPairs = Set<Set<Int>>()
		for seed in 0 ..< 64 {
			var previous = Set<Int>()
			for level: UInt8 in 0 ... 3 {
				let terrain = Scenario.cornerTerrain(seaLevel: level, seed: seed)
				let sea = Set(terrain.indices.filter { terrain[$0].isSea })
				let expected = level == 0 ? 0 : Int(level) + 1
				#expect(sea.count == expected, "Sea level \(level) produced \(sea.count) squares for seed \(seed)")
				#expect(previous.isSubset(of: sea), "Sea level \(level) was not cumulative for seed \(seed)")
				previous = sea
				switch level {
				case 1:
					observedPairs.insert(sea)
					#expect(validPairs.contains(sea), "Sea squares \(sea) do not form a corner pair for seed \(seed)")
				case 2:
					#expect(validCorners.contains(sea), "Sea squares \(sea) do not form a corner for seed \(seed)")
				case 3:
					#expect(validCoasts.contains(sea), "Sea squares \(sea) do not form a coast for seed \(seed)")
				default: break
				}
			}
		}
		#expect(observedPairs == validPairs, "Seeded sea did not use all four corners")
	}

	@Test func riversOnlyTouchSeaAtTerminalMouths() {
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea
		terrain[3] = .sea
		var mouths = 0
		for seed in 0 ..< 24 {
			let map = Map<32, Terrain>(seed: seed, players: 4, terrain: terrain)
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
		var terrain = [9 of Terrain](repeating: .field)
		terrain[0] = .sea
		terrain[1] = .sea
		terrain[3] = .sea
		for seed in 0 ..< 16 {
			let map = Map<32, Terrain>(seed: seed, players: 4, terrain: terrain)

			func landmass(from start: XY, into visited: inout Set<XY>) -> [XY] {
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

			var visited = Set<XY>()
			let mainland = Set(landmass(from: XY(map.size / 2, map.size / 2), into: &visited))

			var islands = 0
			for start in map.indices where !map[start].isSea && !visited.contains(start) {
				islands += 1
				let island = landmass(from: start, into: &visited)
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
			let map = Map<32, Terrain>(seed: seed)
			var cities = [] as [XY]
			for xy in map.indices where map[xy] == .city { cities.append(xy) }
			guard let first = cities.first else {
				Issue.record("No cities for seed \(seed)")
				continue
			}
			var seen = Set([first])
			var stack = [first]
			while let xy = stack.popLast() {
				let n4 = xy.n4
				for i in n4.indices {
					let p = n4[i]
					if map.contains(p), map[p].hasRoad, !seen.contains(p) {
						seen.insert(p)
						stack.append(p)
					}
				}
			}
			for c in cities where !seen.contains(c) {
				Issue.record("City \(c) off the road network for seed \(seed)")
			}
		}
	}

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors. Diagonal-only adjacency would mean the river
		// was disconnected.
		for seed in [3, 11, 23] {
			let map = Map<32, Terrain>(seed: seed)
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
			let map = Map<32, Terrain>(seed: seed)
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
			let base = Map<32, Terrain>(seed: seed)
			var map = clone(base)
			map.placeForts(around: cities(of: base), level: 3)
			var forts = 0
			for xy in map.indices {
				if map[xy] == .fort {
					forts += 1
					switch base[xy] {
					case .field, .forest, .hill: break
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
			var map = Map<32, Terrain>(seed: seed)
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
				var map = Map<32, Terrain>(seed: seed)
				let centers = cities(of: map)
				map.placeForts(around: centers, level: level)
				var count = 0
				for xy in map.indices where map[xy] == .fort { count += 1 }
				return count
			}
			#expect(forts(3) >= forts(1), "Level 3 placed fewer forts than level 1 for seed \(seed)")
			#expect(forts(3) <= 3 * 3 * 32 / 4, "Level 3 exceeded the fort cap for seed \(seed)")
		}
	}

	@Test func fortsSpreadAcrossAllCities() {
		// Round-robin placement: every city whose ring has open ground
		// must get at least one fort, even at the lowest level.
		for seed in [0, 7, 42] {
			let base = Map<32, Terrain>(seed: seed)
			var map = clone(base)
			let centers = cities(of: base)
			map.placeForts(around: centers, level: 1)
			for c in centers {
				let ring = c.r12
				var open = false
				var fort = false
				for i in ring.indices {
					switch base[ring[i]] {
					case .field, .forest, .hill: open = true
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
			var a = Map<32, Terrain>(seed: seed)
			var b = Map<32, Terrain>(seed: seed)
			let centers = cities(of: a)
			a.placeForts(around: centers, level: 3)
			b.placeForts(around: centers, level: 3)
			for xy in a.indices where a[xy] != b[xy] {
				Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
				break
			}
		}
	}

	private func cities(of map: borrowing Map<32, Terrain>) -> [XY] {
		map.indices.compactMap { xy in map[xy] == .city ? xy : nil }
	}

	@Test func riversReachTheMapEdge() {
		// River mouths sit on map edges by construction, so every generated
		// map must have at least one river tile on its border.
		for seed in [3, 11, 23] {
			let map = Map<32, Terrain>(seed: seed)
			var touches = false
			for xy in map.indices where map[xy].isRiver && map.edge(at: xy) != nil {
				touches = true; break
			}
			#expect(touches, "No river touches the map edge for seed \(seed)")
		}
	}
}
