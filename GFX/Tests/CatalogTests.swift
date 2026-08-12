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

	@Test func unitsStandOnTheBaseDiamond() {
		for entry in Catalog.units {
			let bitmap = entry.renderer.render(entry.model)
			let occupied = bitmap.occupied!

			#expect(occupied.y.upperBound <= 47, "\(entry.name) stays on the tile")
			#expect(occupied.y.upperBound >= 32, "\(entry.name) sits on the ground")
			#expect(occupied.x.count <= 40, "\(entry.name) is narrower than a tile")
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
