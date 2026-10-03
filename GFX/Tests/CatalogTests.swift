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

			#expect(occupied.y.upperBound <= 47, "\(shape) stays on the tile")
			// Wings and hulls run longer than a ground vehicle, as the hand-drawn ones did.
			#expect(occupied.x.count <= (shape.flies ? 48 : 44), "\(shape) is no wider than a tile in either facing")
		}
	}

	@Test func groundUnitsStandOnTheBaseDiamondAndAircraftHoverOverIt() {
		for shape in Units.Shape.allCases {
			let occupied = Renderer.unit.render(shape.model).occupied!

			if shape.flies {
				#expect(occupied.y.upperBound < 32, "\(shape) is clear of the ground")
			} else {
				#expect(occupied.y.upperBound >= 32, "\(shape) sits on the ground")
			}
		}
	}

	@Test func uavWingsExposeEqualTopAreasInBothFacings() {
		for model in [Aircraft.drone, Aircraft.drone.mirrored()] {
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

			#expect(occupied.y.upperBound <= 39)
			#expect(occupied.y.lowerBound >= 0)
		}
	}

	@Test func rotationMovesAVillageAroundTheTile() {
		let renderer = Renderer.tile
		let centres = Direction.allCases.map { direction -> (x: Int, y: Int) in
			let occupied = renderer.render(Settlements.village(facing: direction)).occupied!
			return ((occupied.x.lowerBound + occupied.x.upperBound) / 2, (occupied.y.lowerBound + occupied.y.upperBound) / 2)
		}

		#expect(Set(centres.map { "\($0.x),\($0.y)" }).count == 4, "each facing sits somewhere else")
	}

	@Test func imagesCarryTheRenderedPixels() {
		let bitmap = Renderer.unit.render(Units.truck)
		let image = bitmap.cgImage

		#expect(image?.width == 64)
		#expect(image?.height == 48)
		#expect(bitmap.png != nil)
	}
}
