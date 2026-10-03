import Testing
@testable import GFX

struct UnitVariantTests {

	@Test(arguments: Units.Kind.allCases)
	func eachFamilyHasThreeDistinctFactionSprites(kind: Units.Kind) {
		#expect(kind.variants.count >= 3, "\(kind.name) needs at least three concrete platforms")
		let representatives = Units.Faction.allCases.map { kind.variant(for: $0) }
		#expect(Set(representatives).count == 3, "opposing equipment families use different platforms")
		for mirrored in [false, true] {
			let bitmaps = kind.variants.map {
				Renderer.unit.render(mirrored ? $0.model.mirrored() : $0.model)
			}
			for a in bitmaps.indices {
				for b in bitmaps.indices where a < b {
					#expect(bitmaps[a].gray != bitmaps[b].gray || bitmaps[a].alpha != bitmaps[b].alpha,
						"\(kind.variants[a].name) and \(kind.variants[b].name) must differ in both facings")
				}
			}
		}
	}

	@Test func familiesCoverEveryVehicleExactlyOnce() {
		let shapes = Units.Kind.allCases.flatMap(\.variants)
		#expect(shapes.count == Set(shapes).count)
		#expect(Set(shapes) == Set(Units.Shape.allCases).subtracting([.rifleman, .special, .quad]))
		#expect(Set(Units.Shape.allCases.map(\.name)).count == Units.Shape.allCases.count)
	}

	@Test(arguments: Units.Shape.allCases)
	func everyFacingFitsWithoutClipping(shape: Units.Shape) {
		// Render on a larger canvas so parts outside the normal sprite cannot be silently cropped.
		let renderer = Renderer(canvas: Canvas(width: 96, height: 80))
		for model in [shape.model, shape.model.mirrored()] {
			let bounds = renderer.render(model).occupied!
			#expect(bounds.x.lowerBound >= 16 && bounds.x.upperBound < 80, "\(shape.name) fits horizontally")
			#expect(bounds.y.lowerBound >= 32 && bounds.y.upperBound < 80, "\(shape.name) fits vertically")
		}
	}
}
