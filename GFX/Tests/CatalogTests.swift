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
				model.solids[$0].tone == Aircraft.Tone.wing && model.solids[$0].to.z == Aircraft.altitude + 7.5
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

	@Test func citiesAndAirfieldsStayInsideTheTileFrame() {
		let interior = Tiles.interior(on: .tile)
		for entry in Catalog.settlements where entry.renderer.outline == .building {
			let bitmap = entry.renderer.render(entry.model)
			#expect(zip(bitmap.alpha, interior).allSatisfy { $0 == 0 || $1 }, "\(entry.name) fits inside the tile frame")
		}
	}

	@Test(arguments: Tiles.Variant.allCases)
	func cityHasVisibleCrossroads(variant: Tiles.Variant) {
		let city = Settlements.city(variant: variant)
		#expect(city.lines.isEmpty)
		expectVisibleRoad(city, along: .x)
		expectVisibleRoad(city, along: .y)
	}

	@Test func airfieldKeepsItsDashedRunwayCenterline() {
		let airfield = Settlements.airfield
		let bitmap = Renderer.building.render(airfield)
		#expect(airfield.lines.contains { line in
			line.dash != nil && line.tone > Roads.Tone.bed && bitmap.gray.contains(line.tone)
		})
	}

	@Test func fortVariantsStayInsideTheTileFrame() {
		let interior = Tiles.interior(on: .tile)
		let trenches = Tiles.Variant.allCases.map { Renderer.decal.render(Settlements.fort(variant: $0)) }
		#expect(Set(trenches.map(\.rgba)).count == trenches.count)
		for trench in trenches {
			#expect(zip(trench.alpha, interior).allSatisfy { $0 == 0 || $1 })
		}
	}

	@Test(arguments: Tiles.Variant.allCases)
	func gridlessTrenchExitsReachTheEdgeMidpoints(variant: Tiles.Variant) {
		let exits: Set<Direction> = switch variant {
		case .first: [.yMinus, .yPlus]
		case .second: [.xMinus, .xPlus]
		case .third: [.xMinus, .yMinus]
		case .fourth: [.xPlus, .yPlus]
		}
		let model = Settlements.fort(variant: variant, framed: false)
		let bitmap = Renderer.decal.render(model)
		let canvas = Canvas.tile
		let side = Volume.footprint
		for direction in Direction.allCases {
			let alongX = direction.axis == .x
			var edgePixels = 0
			for y in 0 ..< canvas.height {
				for x in 0 ..< canvas.width {
					let ray = canvas.origin(x: x, y: y)
					let along = (alongX ? ray.x : ray.y) - ray.z
					let across = (alongX ? ray.y : ray.x) - ray.z
					let fromEnd = direction == .xPlus || direction == .yPlus ? side - along : along
					guard (0 ..< 1).contains(fromEnd), abs(across - side / 2) < 0.5 else { continue }
					let pixel = bitmap[x, y]
					#expect(pixel.alpha == (exits.contains(direction) ? 255 : 0))
					if exits.contains(direction) { #expect(pixel.gray == 99) }
					edgePixels += 1
				}
			}
			#expect(edgePixels > 0)
		}
	}

	private func expectVisibleRoad(_ model: Model, along axis: Axis) {
		let raster = Renderer.building.raster(model)
		let roadIDs = model.solids.indices.filter { model.solids[$0].to.z == 0 }.map { Int32($0) }
		let half = Volume.footprint / 2
		let samples = 32
		for step in 1 ..< samples {
			let offset = Volume.footprint * Float(step) / Float(samples)
			let point = axis == .x ? V3(offset, half, 0) : V3(half, offset, 0)
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
