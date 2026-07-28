import Testing
@testable import COR

struct CellularTests {

	// MARK: - Torus

	@Test func neighborsWrapAcrossEveryEdge() {
		#expect(XY(-1, -1).wrapped(32) == XY(31, 31))
		#expect(XY(32, 32).wrapped(32) == XY(0, 0))
		#expect(XY(-3, 34).wrapped(32) == XY(29, 2))
		#expect(XY(15, 15).wrapped(32) == XY(15, 15))
	}

	/// A cluster in the corner must reach across the seam, which it can only do
	/// if the automaton wraps.
	@Test func upliftCrossesTheSeam() {
		var map = flat()
		// Exactly the five cells of XY(0,0)'s Moore neighborhood that lie on
		// the far side of a seam. Without wrapping the origin sees none of
		// them and its neighborhood sums to zero.
		for xy in [XY(31, 1), XY(31, 0), XY(31, 31), XY(0, 31), XY(1, 31)] {
			map[xy] = .mountain
		}

		var rule = Cellular()
		rule.kind = .terrace
		rule.rise = 0 // sum ≥ 9 of 16
		rule.noise = 0

		var d20 = D20(seed: 1)
		map.cellular(rule, steps: 1, d20: &d20)

		#expect(map[XY(0, 0)].elevationLevel == 1)
	}

	// MARK: - Synchronous update

	/// Half-turn rotation about the origin is an isometry of the torus and
	/// commutes with a synchronous update, so a symmetric start must stay
	/// symmetric. Reading and writing one buffer instead lets a change
	/// propagate within a generation, dragging the pattern along the row-major
	/// scan and breaking the symmetry.
	@Test func stepReadsASnapshotNotItsOwnOutput() {
		func rot(_ xy: XY) -> XY { XY((32 - xy.x) % 32, (32 - xy.y) % 32) }

		var d20 = D20(seed: 8)
		var map = flat()
		for xy in map.indices {
			let terrain = Terrain.ground(Int(d20.next() % 3), wooded: false)
			map[xy] = terrain
			map[rot(xy)] = terrain
		}

		for kind in Cellular.Kind.allCases {
			var rule = Cellular()
			rule.kind = kind
			rule.noise = 0 // any RNG draw would break the symmetry by itself

			var stepped = clone(map)
			stepped.cellular(rule, steps: 8, d20: &d20)

			for xy in stepped.indices {
				#expect(
					stepped[xy] == stepped[rot(xy)],
					"\(kind) broke half-turn symmetry at \(xy)"
				)
			}
		}
	}

	// MARK: - Write-on-change

	@Test func lowlandStructuresSurviveUntilTheGroundMoves() {
		var map = flat()
		for y in 0 ..< 32 {
			map[XY(5, y)] = .river
		}
		map[XY(20, 20)] = .city

		var rule = Cellular()
		rule.kind = .terrace
		rule.noise = 0

		var d20 = D20(seed: 7)
		map.cellular(rule, steps: 20, d20: &d20)

		// Nothing around them ever rises, so their level never moves and they
		// are left bit-identical.
		for y in 0 ..< 32 {
			#expect(map[XY(5, y)] == .river)
		}
		#expect(map[XY(20, 20)] == .city)
	}

	@Test func risingGroundConsumesAStructure() {
		var map = flat()
		map[XY(16, 16)] = .river
		let ring = XY(16, 16).n8
		for i in ring.indices { map[ring[i]] = .mountain }

		var rule = Cellular()
		rule.kind = .terrace
		rule.rise = 0 // ≥2 of 8
		rule.noise = 0

		var d20 = D20(seed: 1)
		map.cellular(rule, steps: 1, d20: &d20)

		#expect(map[XY(16, 16)] == .hill)
	}

	@Test func woodedTilesKeepTheirTreesAcrossAHeightChange() {
		var map = flat()
		map[XY(16, 16)] = .forest
		let ring = XY(16, 16).n8
		for i in ring.indices { map[ring[i]] = .mountain }

		var rule = Cellular()
		rule.kind = .terrace
		rule.rise = 0
		rule.noise = 0

		var d20 = D20(seed: 1)
		map.cellular(rule, steps: 1, d20: &d20)

		#expect(map[XY(16, 16)] == .forestHill)
	}

	// MARK: - Range and determinism

	@Test func everyRuleStaysInsideTheThreeLevels() {
		for kind in Cellular.Kind.allCases {
			for neighborhood in UInt8(0) ... 2 {
				var rule = Cellular()
				rule.kind = kind
				rule.neighborhood = neighborhood
				rule.rise = 1
				rule.fall = 1
				rule.noise = 3

				var d20 = D20(seed: 3)
				var map = flat()
				map.scatterHeights(d20: &d20)
				map.cellular(rule, steps: 12, d20: &d20)

				for xy in map.indices {
					#expect(
						(0 ... 2).contains(map[xy].elevationLevel),
						"\(kind)/\(neighborhood) produced level \(map[xy].elevationLevel) at \(xy)"
					)
				}
			}
		}
	}

	/// The failure mode worth guarding: a threshold outside its useful band
	/// flattens the whole map to one level on the first generation, so the knob
	/// silently does nothing useful. Every kind × neighbourhood × knob must
	/// leave at least two levels standing.
	@Test func noConfigurationCollapsesToASingleLevel() {
		for kind in Cellular.Kind.allCases {
			for neighborhood in UInt8(0) ... 2 {
				for knob in UInt8(0) ... 3 {
					var rule = Cellular()
					rule.kind = kind
					rule.neighborhood = neighborhood
					rule.rise = knob
					rule.fall = knob
					rule.noise = 0

					var d20 = D20(seed: 42)
					var map = flat()
					map.scatterHeights(d20: &d20)
					map.cellular(rule, steps: 24, d20: &d20)

					var seen = Set<Int>()
					for xy in map.indices { seen.insert(map[xy].elevationLevel) }
					#expect(
						seen.count > 1,
						"\(kind) nb=\(neighborhood) knob=\(knob) collapsed to level \(seen)"
					)
				}
			}
		}
	}

	@Test func sameSeedAndRuleProduceTheSameMap() {
		func run() -> [Terrain] {
			var d20 = D20(seed: 99)
			var map = flat()
			map.scatterHeights(d20: &d20)

			var rule = Cellular()
			rule.kind = .cyclic
			rule.noise = 2
			map.cellular(rule, steps: 10, d20: &d20)

			return map.indices.map { map[$0] }
		}

		#expect(run() == run())
	}

	// MARK: - Liveness

	/// The cyclic rule's whole point is that it never settles. If a change
	/// breaks the wave fronts it degenerates into a fixed point.
	@Test func cyclicKeepsMovingAfterTwentySteps() {
		var d20 = D20(seed: 5)
		var map = flat()
		map.scatterHeights(d20: &d20)

		var rule = Cellular()
		rule.kind = .cyclic
		rule.noise = 0

		map.cellular(rule, steps: 20, d20: &d20)
		let before = map.indices.map { map[$0].elevationLevel }

		map.cellular(rule, steps: 1, d20: &d20)
		let after = map.indices.map { map[$0].elevationLevel }

		#expect(before != after)
	}

	@Test func ridgesBuildHighgroundFromAScatter() {
		var d20 = D20(seed: 11)
		var map = flat()
		map.scatterHeights(d20: &d20)

		var rule = Cellular()
		rule.kind = .ridges
		rule.noise = 0

		map.cellular(rule, steps: 12, d20: &d20)

		let high = map.indices.count { map[$0].isHighground }
		#expect(high > 0, "ridges flattened the map entirely")
		#expect(high < map.count, "ridges raised every tile")
	}

	// MARK: - Scatter / flatten

	@Test func flattenDropsEveryTileAndKeepsTrees() {
		var d20 = D20(seed: 2)
		var map = flat()
		map.scatterHeights(d20: &d20)
		map[XY(4, 4)] = .forestHill

		map.flattenHeights()

		for xy in map.indices {
			#expect(map[xy].elevationLevel == 0)
		}
		#expect(map[XY(4, 4)] == .forest)
	}

	@Test func scatterUsesAllThreeLevels() {
		var d20 = D20(seed: 4)
		var map = flat()
		map.scatterHeights(d20: &d20)

		var seen = Set<Int>()
		for xy in map.indices { seen.insert(map[xy].elevationLevel) }
		#expect(seen == [0, 1, 2])
	}
}

private func flat() -> Map<32, Terrain> {
	var map = Map<32, Terrain>(zero: .field)
	for xy in map.indices { map[xy] = .field }
	return map
}
