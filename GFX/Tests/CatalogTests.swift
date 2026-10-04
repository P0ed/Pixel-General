import Testing
@testable import GFX

struct CatalogTests {

	@Test(arguments: Catalog.all.map(\.name))
	func everyModelDrawsInsideItsCanvas(name: String) {
		let entry = Catalog.all.first { $0.name == name }!
		let bitmap = entry.renderer.render(entry.model)
		let occupied = bitmap.occupied

		#expect(occupied != nil, "\(name) renders nothing")
		#expect(occupied!.x.lowerBound >= 0 && occupied!.x.upperBound < bitmap.width)
		#expect(occupied!.y.lowerBound >= 0 && occupied!.y.upperBound < bitmap.height)
	}

	@Test(arguments: Units.Shape.allCases)
	func unitsStayWithinReachOfTheirTile(shape: Units.Shape) {
		for model in [shape.model, shape.model.mirrored()] {
			let occupied = Renderer.unit.render(model).occupied!

			#expect(occupied.y.upperBound <= 71, "\(shape) stays on the tile")
			// Wings and hulls run longer than a ground vehicle, as the hand-drawn ones did.
			#expect(occupied.x.count <= (shape.flies ? 72 : 66), "\(shape) is no wider than a tile in either facing")
		}
	}

	@Test func groundUnitsStandOnTheBaseDiamondAndAircraftHoverOverIt() {
		for shape in Units.Shape.allCases {
			let occupied = Renderer.unit.render(shape.model).occupied!

			if shape.flies {
				#expect(occupied.y.upperBound < 48, "\(shape) is clear of the ground")
			} else {
				#expect(occupied.y.upperBound >= 48, "\(shape) sits on the ground")
			}
		}
	}

	@Test func uavWingsExposeEqualTopAreasInBothFacings() {
		for model in [Aircraft.mq9, Aircraft.mq9.mirrored()] {
			// The main wings sit flush with the top of the fuselage.
			let wings = model.solids.indices.filter {
				model.solids[$0].tone == Aircraft.Tone.wing && model.solids[$0].to.z == Aircraft.altitude + 5
			}
			let raster = Renderer.unit.raster(model)
			let areas = wings.map { wing in
				raster.ids.indices.count { raster.ids[$0] == Int32(wing) && raster.faces[$0] == 0 }
			}
			#expect(areas.count == 2)
			#expect(areas.allSatisfy { $0 > 0 })
			#expect(Set(areas).count == 1, "both wings expose the same number of top-face pixels")
		}
	}

	@Test func settlementsNeverSpillOffTheTile() {
		for entry in Catalog.settlements {
			let bitmap = entry.renderer.render(entry.model)
			let occupied = bitmap.occupied!

			#expect(occupied.y.upperBound <= 59)
			#expect(occupied.y.lowerBound >= 0)
		}
	}

	@Test(arguments: Direction.allCases)
	func villageRoadsConnectEveryArmExceptTheNamedSide(facing: Direction) {
		let village = Settlements.village(facing: facing)
		let road = village.solids.filter { $0.tone == Roads.Tone.bed && $0.to.z == 0 }
		let buildings = village.solids.filter { $0.to.z > 0 }
		let exits: [(Direction, V3)] = [
			(.xPlus, V3(32, 16, 0)), (.xMinus, V3(0, 16, 0)),
			(.yPlus, V3(16, 32, 0)), (.yMinus, V3(16, 0, 0)),
		]
		for (direction, edge) in exits {
			#expect(road.contains { $0.contains(edge) } == (direction != facing))
			guard direction != facing else { continue }
			for step in 0 ... 16 {
				let point = Volume.center + (edge - Volume.center) * (Float(step) / 16)
				#expect(road.contains { $0.contains(point) }, "the road stays continuous from the junction to the tile edge")
			}
		}

		for x in 0 ..< 32 {
			for y in 0 ..< 32 {
				let point = V3(Float(x) + 0.5, Float(y) + 0.5, 0)
				guard road.contains(where: { $0.contains(point) }) else { continue }
				#expect(!buildings.contains { $0.contains(point + V3(0, 0, 0.1)) }, "houses leave the carriageway clear")
			}
		}

		expectVisibleRoad(village, along: facing.axis == .x ? .y : .x)
	}

	@Test func cityHasVisibleCrossroads() {
		expectVisibleRoad(Settlements.city, along: .x)
		expectVisibleRoad(Settlements.city, along: .y)
	}

	private func expectVisibleRoad(_ model: Model, along axis: Axis) {
		let raster = Renderer.building.raster(model)
		let roadIDs = model.solids.indices.filter { model.solids[$0].to.z == 0 }.map { Int32($0) }
		for step in 1 ..< 32 {
			let point = axis == .x ? V3(Float(step), 16, 0) : V3(16, Float(step), 0)
			let pixel = Canvas.tile.project(point)
			let id = raster.ids[raster.bitmap.index(x: Int(pixel.x), y: Int(pixel.y))]
			#expect(roadIDs.contains(id), "the road stays visible beneath the projected roofs")
		}
	}

	@Test func imagesCarryTheRenderedPixels() {
		let bitmap = Renderer.unit.render(Units.manKat1)
		let image = bitmap.cgImage

		#expect(image?.width == 96)
		#expect(image?.height == 72)
		#expect(bitmap.png != nil)
	}
}
