import Testing
@testable import COR

struct MapGenerationTests {

	@Test func terminatesAcrossManySeeds() {
		for seed in 0 ..< 16 {
			_ = Map<32, Terrain>(size: 8 + seed % 24, seed: seed)
		}
	}

	@Test func producesNonEmptyMapWithCitiesAndRivers() {
		var emptySeeds: [Int] = []
		var noCitySeeds: [Int] = []
		var noRiverSeeds: [Int] = []

		for seed in 0 ..< 8 {
			let map = Map<32, Terrain>(size: 32, seed: seed * 7)
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

	@Test func isDeterministicForSameSeed() {
		for seed in [0, 1, 7, 100, 999, 1023] {
			let a = Map<32, Terrain>(size: 32, seed: seed)
			let b = Map<32, Terrain>(size: 32, seed: seed)
			for xy in a.indices where a[xy] != b[xy] {
				Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
				break
			}
		}
	}

	@Test func handlesPlayableSizes() {
		// `placeCities` lays cities on a jittered grid whose columns/rows are
		// derived from the city count, so it has no divisor that collapses to
		// zero and works across the full 16...32 range.
		for size in 16 ... 32 {
			let map = Map<32, Terrain>(size: size, seed: 0)
			#expect(map.size == size)
			#expect(map.count == size * size)
			var hasCity = false
			for xy in map.indices where map[xy] == .city { hasCity = true; break }
			#expect(hasCity, "Size \(size) produced no city")
		}
	}

	@Test func terrainBiasRaisesHighground() {
		// A hill/mountain province must generate a battle map with more
		// highground than the plains baseline, and still place cities.
		for seed in [1, 5, 42] {
			func highground(_ terrain: Terrain) -> Int {
				let map = Map<32, Terrain>(size: 24, seed: seed, terrain: terrain)
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

	@Test func roadsConnectAllCities() {
		// MST-based road building links every terrain-reachable city into
		// one network; on these seeds all cities share one landmass, so a
		// flood along road tiles from any city must reach every other.
		for (size, seed) in [(32, 0), (32, 7), (32, 21), (32, 42), (24, 5), (24, 11), (16, 2)] {
			let map = Map<32, Terrain>(size: size, seed: seed)
			var cities = [] as [XY]
			for xy in map.indices where map[xy] == .city { cities.append(xy) }
			guard let first = cities.first else {
				Issue.record("No cities for seed \(seed) size \(size)")
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
				Issue.record("City \(c) off the road network for seed \(seed) size \(size)")
			}
		}
	}

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors. Diagonal-only adjacency would mean the river
		// was disconnected.
		for seed in [3, 11, 23] {
			let map = Map<32, Terrain>(size: 32, seed: seed)
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
			let map = Map<32, Terrain>(size: 32, seed: seed)
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
		for (size, seed) in [(32, 0), (32, 7), (24, 5), (16, 2)] {
			let base = Map<32, Terrain>(size: size, seed: seed)
			var map = clone(base)
			map.placeForts(around: cities(of: base), level: 3)
			var forts = 0
			for xy in map.indices {
				if map[xy] == .fort {
					forts += 1
					switch base[xy] {
					case .field, .forest, .hill: break
					default: Issue.record("Fort replaced \(base[xy]) at \(xy) for seed \(seed) size \(size)")
					}
				} else if map[xy] != base[xy] {
					Issue.record("Fort placement disturbed \(base[xy]) at \(xy) for seed \(seed) size \(size)")
				}
			}
			#expect(forts > 0, "No forts for seed \(seed) size \(size)")
		}
	}

	@Test func fortsRingCitiesAtChebyshevTwo() {
		// Every fort must lie on some city's ring: Chebyshev distance
		// exactly 2 with the four corners cut.
		for seed in [0, 7, 42] {
			var map = Map<32, Terrain>(size: 32, seed: seed)
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
				var map = Map<32, Terrain>(size: 32, seed: seed)
				let centers = cities(of: map)
				map.placeForts(around: centers, level: level)
				var count = 0
				for xy in map.indices where map[xy] == .fort { count += 1 }
				return count
			}
			#expect(forts(3) >= forts(1), "Level 3 placed fewer forts than level 1 for seed \(seed)")
			#expect(forts(3) <= 3 * 32 / 4, "Level 3 exceeded the fort cap for seed \(seed)")
		}
	}

	@Test func fortPlacementIsDeterministic() {
		for seed in [0, 7, 999] {
			var a = Map<32, Terrain>(size: 32, seed: seed)
			var b = Map<32, Terrain>(size: 32, seed: seed)
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
			let map = Map<32, Terrain>(size: 32, seed: seed)
			var touches = false
			for xy in map.indices where map[xy].isRiver && map.edge(at: xy) != nil {
				touches = true; break
			}
			#expect(touches, "No river touches the map edge for seed \(seed)")
		}
	}
}
