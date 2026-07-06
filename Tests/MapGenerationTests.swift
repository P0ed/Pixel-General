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

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors (after `shapeRivers`). Diagonal-only adjacency
		// would mean the river was disconnected.
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
}
