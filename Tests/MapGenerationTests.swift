import Testing
@testable import PG

// Map generation has at least one known failure mode where `placeRivers` can
// loop without ever reaching the river's `end` for some seeds. To keep the
// test suite from hanging while still surfacing those seeds, we run each
// generation on a background queue and wait with a deadline. Threads that miss
// the deadline are abandoned — they keep running until the test process exits,
// but the suite makes progress.

struct MapGenerationTests {

	private static let perSeedDeadline: Double = 8

	@Test func terminatesAcrossManySeeds() {
		var hangingSeeds: [Int] = []

		for seed in 0 ..< 256 {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				_ = Map<Terrain>(size: 8 + seed % 24, seed: seed)
			}
			if !finished { hangingSeeds.append(seed) }
		}

		#expect(
			hangingSeeds.isEmpty,
			"Seeds that exceeded \(Self.perSeedDeadline)s during generation: \(hangingSeeds)"
		)
	}

	@Test func producesNonEmptyMapWithCitiesAndRivers() {
		// Seed-keyed observations recorded inside each closure. Access is
		// sequential — the main thread blocks on a semaphore until each
		// closure signals — so no lock is needed, only the unsafe-isolation
		// hint to satisfy strict concurrency.
		nonisolated(unsafe) var emptySeeds: [Int] = []
		nonisolated(unsafe) var noCitySeeds: [Int] = []
		nonisolated(unsafe) var noRiverSeeds: [Int] = []

		for seed in 0 ..< 32 {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: 32, seed: seed)
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
			#expect(finished, "Seed \(seed) hung at generation")
		}

		#expect(emptySeeds.isEmpty, "Seeds that produced an all-`.none` map: \(emptySeeds)")
		#expect(noCitySeeds.isEmpty, "Seeds with no city: \(noCitySeeds)")
		#expect(noRiverSeeds.isEmpty, "Seeds with no river: \(noRiverSeeds)")
	}

	@Test func isDeterministicForSameSeed() {
		// Cells are compared inside a single closure because Map is ~Copyable
		// and cannot escape; we compare two generations directly.
		// Seeds known to hang at river creation (42, 77) are excluded so this
		// test stays focused on the determinism property.
		for seed in [0, 1, 7, 100, 999, 1023] {
			let finished = runWithDeadline(Self.perSeedDeadline * 2) {
				let a = Map<Terrain>(size: 32, seed: seed)
				let b = Map<Terrain>(size: 32, seed: seed)
				for xy in a.indices {
					if a[xy] != b[xy] {
						Issue.record("Map differs at \(xy) for seed \(seed): \(a[xy]) vs \(b[xy])")
						break
					}
				}
			}
			#expect(finished, "Seed \(seed) hung at generation")
		}
	}

	@Test func handlesPlayableSizes() {
		// `placeCities` lays cities on a jittered grid whose columns/rows are
		// derived from the city count, so it has no divisor that collapses to
		// zero and works across the full 8...32 range. `placeRivers` branches
		// on `riversCount == 1` (count <= 288 cells) vs the multi-river setup,
		// so this range exercises both regimes.
		for size in 8 ... 32 {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: size, seed: 0)
				#expect(map.size == size)
				#expect(map.count == size * size)
				var hasCity = false
				for xy in map.indices where map[xy] == .city { hasCity = true; break }
				#expect(hasCity, "Size \(size) produced no city")
			}
			#expect(finished, "Size \(size) seed 0 hung")
		}
	}

	@Test func riversAreContiguousAndOrthogonal() {
		// A river tile must touch another river/bridge through one of its 4
		// orthogonal neighbors (after `shapeRivers`). Diagonal-only adjacency
		// would mean the river was disconnected.
		for seed in [3, 11, 23] {
			let finished = runWithDeadline(Self.perSeedDeadline) {
				let map = Map<Terrain>(size: 32, seed: seed)
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
			#expect(finished, "Seed \(seed) hung")
		}
	}
}

