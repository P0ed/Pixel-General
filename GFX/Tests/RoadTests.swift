import Testing
@testable import GFX

struct RoadTests {

	@Test(arguments: Axis.allCases)
	func roadExitsLeaveOnlyTheTileFrame(axis: Axis) {
		let directions: [Direction] = axis == .x ? [.xMinus, .xPlus] : [.yMinus, .yPlus]
		let model = Roads.road(directions)
		let road = Renderer.decal.render(model)
		let fill = Renderer.decal.fill(model)
		let frame = Renderer.tile.edges(Tiles.base(elevation: 0))
		let half = Volume.footprint / 2

		for y in 0 ..< road.height {
			for x in 0 ..< road.width {
				if frame[x, y].alpha > 0 {
					#expect(road[x, y].alpha == 0, "pavement leaves the tile frame visible")
					continue
				}

				let ray = Canvas.tile.origin(x: x, y: y)
				let along = (axis == .x ? ray.x : ray.y) - ray.z
				let across = (axis == .x ? ray.y : ray.x) - ray.z
				let fromEnd = min(along, Volume.footprint - along)
				guard fromEnd > 0, fromEnd < 1.5, abs(across - half) < Roads.width / 2 - 1 else { continue }
				#expect(road[x, y].alpha == 255, "pavement reaches the tile frame")
				#expect(road[x, y].gray == fill[x, y].gray, "road exits have no end cap")
			}
		}
	}

	@Test(arguments: [nil] + Direction.allCases.map(Optional.some))
	func settlementRoadEdgesMatchOpenRoads(missingArm: Direction?) {
		let model = missingArm.map { Settlements.village(facing: $0) } ?? Settlements.city
		var road = Roads.road(Direction.allCases.filter { $0 != missingArm })
		for i in road.solids.indices { road.solids[i].outline = nil }
		let expected = Renderer.decal.edges(road)
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

	@Test(arguments: [nil] + Direction.allCases.map(Optional.some))
	func settlementBuildingsKeepTheirOutlinesOverPavement(missingArm: Direction?) {
		let settlement = missingArm.map { Settlements.village(facing: $0) } ?? Settlements.city
		let buildings = Model(settlement.solids.filter { $0.to.z > 0 })
		let expected = Renderer.building.edges(buildings)
		let actual = Renderer.building.render(settlement)

		for i in expected.alpha.indices where expected.alpha[i] > 0 {
			#expect(actual.alpha[i] == expected.alpha[i] && actual.gray[i] == expected.gray[i],
				"building outlines stay visible against the pavement")
		}
	}

	@Test(arguments: Axis.allCases)
	func bridgeContinuesThePavementAndMarkingsOfAdjoiningRoads(axis: Axis) {
		let directions: [Direction] = axis == .x ? [.xMinus, .xPlus] : [.yMinus, .yPlus]
		let road = Renderer.decal.render(Roads.road(directions))
		let bridge = Renderer.decal.render(Roads.bridge(along: axis))
		let expected = joined([road, road, road], along: axis)
		let actual = joined([road, bridge, road], along: axis)

		for i in expected.alpha.indices where expected.alpha[i] > 0 {
			#expect(actual.alpha[i] == 255, "the road–bridge joins must not expose holes")
			if expected.gray[i] == Roads.Tone.bed || expected.gray[i] == Roads.Tone.mark {
				#expect(actual.gray[i] == expected.gray[i], "asphalt and center stripes continue across the span")
			}
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
