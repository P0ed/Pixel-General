import Testing
@testable import GFX

struct RendererTests {

	private let flat = Renderer(canvas: .unit, outline: .none)

	@Test func baseDiamondFillsTheBottomOfTheCanvas() {
		let bitmap = flat.render(Tiles.base(elevation: 0))
		let occupied = bitmap.occupied

		#expect(occupied?.y == 16 ... 47, "the 64x32 base sits below 16 px of headroom")
		#expect(bitmap.width == 64 && bitmap.height == 48)
	}

	@Test func tileCanvasKeepsEightPixelsOfHeadroom() {
		let bitmap = Renderer(canvas: .tile, outline: .none).render(Tiles.base(elevation: 0))
		#expect(bitmap.occupied?.y == 8 ... 39)
	}

	@Test func elevationRaisesTheTopFaceByFourPixelsPerLevel() {
		let renderer = Renderer(canvas: .tile, outline: .none)
		for elevation in 0 ... 2 {
			let bitmap = renderer.render(Tiles.base(elevation: elevation))
			#expect(bitmap.occupied?.y.lowerBound == 8 - elevation * 4)
			#expect(bitmap.occupied?.y.upperBound == 39, "the footprint stays put")
		}
	}

	@Test func anchorSitsOnTheCentreOfTheBaseDiamond() {
		#expect(Canvas.unit.anchor.y == 16 as Float / 48)
		#expect(Canvas.tile.anchor.y == 16 as Float / 40)

		// The centre of the footprint projects onto that anchor row.
		let centre = Canvas.unit.project(Volume.center)
		#expect(centre.x == 32)
		#expect(Float(Canvas.unit.height) - centre.y == 16)
	}

	@Test func cardinalFacesMatchTheHandDrawnRamp() {
		let bitmap = flat.render(Model(.box(from: V3(8, 8, 0), to: V3(24, 24, 8))))
		let light = Light.topLeft

		#expect(light.gray(V3(0, 0, 1), tone: .max) == 255, "top face")
		#expect(light.gray(V3(0, 1, 0), tone: .max) == 209, "screen-left face")
		#expect(light.gray(V3(1, 0, 0), tone: .max) == 171, "screen-right face")

		let grays = Set(bitmap.gray.enumerated().filter { bitmap.alpha[$0.offset] > 0 }.map(\.element))
		#expect(grays == [255, 209, 171])
	}

	@Test func toneScalesEveryFace() {
		let bitmap = flat.render(Model(.box(from: V3(8, 8, 0), to: V3(24, 24, 8), tone: 128)))
		let grays = Set(bitmap.gray.enumerated().filter { bitmap.alpha[$0.offset] > 0 }.map(\.element))

		#expect(grays == [128, 105, 86])
	}

	@Test func nearerSolidHidesTheOneItSitsInFrontOf() {
		let far = Solid.box(from: V3(4, 4, 0), to: V3(12, 12, 8), tone: 128)
		// (1,1,1) is the view direction, so this box projects onto exactly the same pixels.
		let near = far.translated(by: V3(8, 8, 8)).toned(.max)
		let both = flat.render(Model([far, near]))
		let alone = flat.render(Model(near))

		#expect(both.gray == alone.gray)
		#expect(both.alpha == alone.alpha)
		#expect(!both.gray.contains(128))
	}

	@Test func wedgeRisesTowardsItsDirection() {
		let high = V3(28, 16, 7)
		let low = V3(4, 16, 7)

		#expect(Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .xPlus).contains(high))
		#expect(!Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .xPlus).contains(low))
		#expect(Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .xMinus).contains(low))
		#expect(Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .yPlus).contains(V3(16, 28, 7)))
		#expect(!Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .yMinus).contains(V3(16, 28, 7)))
		#expect(Solid.wedge(from: .zero, to: V3(32, 32, 8), rising: .xPlus).contains(V3(4, 16, 0.5)), "the low end is still solid")
	}

	@Test func gablePeaksAtItsRidge() {
		let roof = Solid.gable(from: V3(8, 8, 0), to: V3(24, 24, 8), ridge: .x)

		#expect(roof.contains(V3(16, 16, 7.5)), "under the ridge")
		#expect(!roof.contains(V3(16, 9, 7.5)), "under the eave")
		#expect(roof.contains(V3(16, 9, 0.5)))
		#expect(roof.contains(V3(16, 23, 0.5)), "both eaves reach the ground")
	}

	@Test func pyramidNarrowsTowardsItsApex() {
		let spire = Solid.pyramid(from: V3(8, 8, 0), to: V3(24, 24, 8))

		#expect(spire.contains(V3(16, 16, 7.5)), "under the apex")
		#expect(!spire.contains(V3(9, 9, 7.5)), "above the corner")
		#expect(spire.contains(V3(9, 9, 0.5)))
	}

	@Test func swappingTheRidgeMirrorsTheRoof() {
		let along = flat.render(Model(.gable(from: V3(8, 8, 0), to: V3(24, 24, 8), ridge: .x)))
		let across = flat.render(Model(.gable(from: V3(8, 8, 0), to: V3(24, 24, 8), ridge: .y)))

		for y in 0 ..< along.height {
			let row = (0 ..< along.width).map { along.alpha[along.index(x: $0, y: y)] }
			let mirrored = (0 ..< across.width).map { across.alpha[across.index(x: $0, y: y)] }
			#expect(row == mirrored.reversed(), "row \(y)")
		}
		#expect(along.gray != across.gray, "the light still favours the screen-left slope")
	}

	@Test func silhouetteOutlineNeverGrowsTheSprite() {
		let model = Units.tank
		let plain = flat.render(model)
		let outlined = Renderer(canvas: .unit, outline: .unit).render(model)

		#expect(plain.alpha == outlined.alpha)
		#expect(zip(plain.gray, outlined.gray).allSatisfy { $1 <= $0 })
		#expect(outlined.gray.contains(24), "the rim is drawn")
	}

	@Test func quantizationSnapsToTheRequestedLevels() {
		#expect(Light.quantize(255, levels: 16) == 255)
		#expect(Light.quantize(209, levels: 16) == 204)
		#expect(Light.quantize(209, levels: nil) == 209)
	}
}
