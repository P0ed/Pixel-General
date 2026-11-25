import Testing
@testable import GFX

struct RoadTests {

	@Test(arguments: Axis.allCases)
	func roadExitsRevealTheGrid(axis: Axis) {
		let side = Volume.footprint
		let half = side / 2
		let near = half - Roads.width / 2
		let far = half + Roads.width / 2
		let from = axis == .x ? V3(-3, near, 0) : V3(near, -3, 0)
		let to = axis == .x ? V3(side + 3, far, 0) : V3(far, side + 3, 0)
		let reference = Renderer.decal.render(Model(.box(from: from, to: to, tone: Roads.Tone.bed)))
		let directions: [Direction] = axis == .x ? [.xMinus, .xPlus] : [.yMinus, .yPlus]
		let straight = Renderer.decal.render(Roads.road(directions))
		let midArm = straight.width * 3 / 8
		#expect((0 ..< straight.height).count { straight[midArm, $0].alpha > 0 } == Int(Roads.width))

		let roads = [
			straight,
			Renderer.decal.render(Roads.road(Direction.allCases)),
			Renderer.decal.render(Roads.bridge(along: axis)),
		]
			+ Tiles.Variant.allCases.map { variant in
				Renderer.building.render(Settlements.city(variant: variant))
			}
		let grid = Tiles.grid

		for y in 0 ..< reference.height {
			for x in 0 ..< reference.width where reference[x, y].alpha > 0 {
				let ray = Canvas.tile.origin(x: x, y: y)
				let along = (axis == .x ? ray.x : ray.y) - ray.z
				let fromEnd = min(along, side - along)
				guard abs(fromEnd) < 2 else { continue }
				for road in roads {
					if fromEnd >= 0 && grid[x, y].alpha == 0 {
						#expect(road[x, y] == reference[x, y], "pavement meets the grid with its side outlines intact")
					} else {
						#expect(road[x, y].alpha == 0, "pavement leaves the grid visible at the join")
					}
				}
			}
		}
	}

	@Test(arguments: [nil] + Direction.allCases.map(Optional.some))
	func junctionsAreFlatAndEndBeforeTheGrid(missingArm: Direction?) throws {
		let name = missingArm.map { "Road-T-\($0)" } ?? "Road-X"
		let entry = try #require(Catalog.roads.first { $0.name == name })
		let road = entry.model.solids
		#expect(entry.model.lines.isEmpty)
		#expect(road.allSatisfy { $0.from.z == 0 && $0.to.z == 0 && $0.tone == Roads.Tone.bed })

		let side = Volume.footprint
		let half = side / 2
		let exits: [(Direction, V3)] = [
			(.xPlus, V3(side, half, 0)), (.xMinus, V3(0, half, 0)),
			(.yPlus, V3(half, side, 0)), (.yMinus, V3(half, 0, 0)),
		]
		for (direction, edge) in exits {
			#expect(!road.contains { $0.contains(edge) })
			let end = edge + (Volume.center - edge) * (0.5 / half)
			#expect(road.contains { $0.contains(end) } == (direction != missingArm))
			guard direction != missingArm else { continue }
			for step in 0 ... 16 {
				let point = Volume.center + (end - Volume.center) * (Float(step) / 16)
				#expect(road.contains { $0.contains(point) })
			}
		}
	}

	@Test func cityRoadEdgesMatchOpenRoads() {
		let model = Settlements.city
		let expected = Renderer.decal.edges(Roads.road(Direction.allCases))
		let actual = Renderer.building.edges(model)
		let raster = Renderer.building.raster(model)
		let pavement = raster.ids.indices.filter { i in
			let id = raster.ids[i]
			return id >= 0 && model.solids[Int(id)].to.z == 0
		}
		let outlined = pavement.filter { actual.alpha[$0] > 0 }
		#expect(!outlined.isEmpty, "settlement roads still have side edges")
		for i in outlined {
			#expect(actual.alpha[i] == expected.alpha[i], "the junction has no internal seams")
			#expect(actual.gray[i] == expected.gray[i], "pavement uses the regular road outline tone")
		}
	}

	@Test func cityBuildingsKeepTheirOutlinesOverPavement() {
		let city = Settlements.city
		let buildings = Model(city.solids.filter { $0.to.z > 0 })
		let expected = Renderer.building.edges(buildings)
		let actual = Renderer.building.render(city)

		for i in expected.alpha.indices where expected.alpha[i] > 0 {
			#expect(actual.alpha[i] == expected.alpha[i] && actual.gray[i] == expected.gray[i],
				"building outlines stay visible against the pavement")
		}
	}

	@Test(arguments: Axis.allCases)
	func bridgeContinuesThePavementOfAdjoiningRoads(axis: Axis) {
		let directions: [Direction] = axis == .x ? [.xMinus, .xPlus] : [.yMinus, .yPlus]
		let road = Renderer.decal.render(Roads.road(directions))
		let bridge = Renderer.decal.render(Roads.bridge(along: axis))
		let expected = joined([road, road, road], along: axis)
		let actual = joined([road, bridge, road], along: axis)

		for i in expected.alpha.indices where expected.alpha[i] > 0 {
			#expect(actual.alpha[i] == 255, "the road–bridge joins must not expose holes")
			#expect(actual.gray[i] == expected.gray[i], "the pavement and its outline continue across the span")
		}
	}

	@Test(arguments: Axis.allCases)
	func bridgePilesAreVisibleBelowThePavement(axis: Axis) {
		let model = Roads.bridge(along: axis)
		let raster = Renderer.decal.raster(model)
		let piles = model.solids.indices.filter { model.solids[$0].tone == Roads.Tone.pile }
		#expect(piles.count == 5)
		for id in piles {
			#expect(model.solids[id].to.z < 0)
			#expect(raster.ids.contains(Int32(id)))
		}
	}

	/// Three neighbouring isometric tiles, composited in map drawing order.
	private func joined(_ tiles: [Bitmap], along axis: Axis) -> Bitmap {
		var result = Bitmap(width: Canvas.tile.width * 2, height: Canvas.tile.height + Canvas.tile.baseHeight)
		for (index, tile) in tiles.enumerated() {
			let originX = (axis == .x ? index : 2 - index) * Canvas.tile.width / 2
			let originY = index * Canvas.tile.baseHeight / 2
			for y in 0 ..< tile.height {
				for x in 0 ..< tile.width where tile[x, y].alpha > 0 {
					result[originX + x, originY + y] = tile[x, y]
				}
			}
		}
		return result
	}
}
