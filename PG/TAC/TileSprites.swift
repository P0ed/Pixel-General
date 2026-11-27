import SpriteKit
import UIKit
import COR
import GFX

enum TileSurface: CaseIterable, Hashable {
	case field, forest, rough, mountain, water, sea

	var color: SKColor {
		switch self {
		case .field: .fieldSurface
		case .forest: .forestSurface
		case .rough: .roughSurface
		case .mountain: .mountainSurface
		case .water: .waterSurface
		case .sea: .seaSurface
		}
	}

	/// Tinted flat surface; terrain surfaces have stable texture.
	@MainActor
	func image(variant: Tiles.Variant = .first) -> CGImage? {
		let image = CGImage.surface.tinted(color.cgColor)
		switch self {
		case .mountain:
			return image?.noised(with: CGImage.harshNoise[variant.rawValue])
		case .forest, .rough:
			return image?.noised(with: CGImage.strongNoise[variant.rawValue])
		case .field, .water, .sea:
			return image?.noised(with: CGImage.noise[variant.rawValue])
		}
	}
}

enum TileOverlay: Hashable {
	case team(Team)
	case country(Country)
	case level(UInt8)

	static let palette = Team.allCases.map(Self.team)
		+ Country.allCases.map(Self.country)
		+ (0 ... 7 as ClosedRange<UInt8>).map(Self.level)

	var color: SKColor {
		switch self {
		case .team(let team): team.color
		case .country(let country): country.color
		case .level(let level): .amberGreen8(level)
		}
	}
}

private extension XY {

	var tileVariant: Tiles.Variant {
		let variants = Tiles.Variant.allCases
		return variants[(x * 64 + y) % variants.count]
	}
}

extension Terrain {

	var tileSurface: TileSurface {
		switch self {
		case .forest: .forest
		case .rough: .rough
		case .mountain: .mountain
		case .river, .bridgeWE, .bridgeSN: .water
		case .sea, .port: .sea
		default: .field
		}
	}

	/// Compass names map onto GFX axes the way `XY.point` puts them on screen:
	/// E is `xPlus`, N `yMinus`, W `xMinus`, S `yPlus`.
	func decoration(variant: Tiles.Variant = .first) -> CGImage.Decoration? {
		switch self {
		case .none, .river, .sea, .field, .forest, .rough, .mountain: nil
		case .city: .city(variant)
		case .fort: .fort(variant)
		case .airfield: .airfield
		case .port: .port
		case .bridgeWE: .bridge(.x)
		case .bridgeSN: .bridge(.y)
		case .roadNW: .road([.yMinus, .xMinus])
		case .roadNE: .road([.yMinus, .xPlus])
		case .roadWE: .road([.xMinus, .xPlus])
		case .roadSN: .road([.yPlus, .yMinus])
		case .roadSW: .road([.yPlus, .xMinus])
		case .roadSE: .road([.yPlus, .xPlus])
		case .roadTE: .road([.xMinus, .yPlus, .yMinus])
		case .roadTN: .road([.xPlus, .xMinus, .yPlus])
		case .roadTW: .road([.xPlus, .yPlus, .yMinus])
		case .roadTS: .road([.xPlus, .xMinus, .yMinus])
		case .roadX: .road(GFX.Direction.allCases)
		}
	}
}

@MainActor
extension SKTileGroup {

	static let fog = overlay(color: .black)

	private struct TerrainKey: Hashable {
		let surface: TileSurface
		let variant: Tiles.Variant
	}
	private static var terrainCache: [TerrainKey: SKTileGroup] = [:]
	private static var decorationCache: [CGImage.Decoration: SKTileGroup] = [:]
	private static var overlayCache: [TileOverlay: SKTileGroup] = [:]
	private static let overlayMask = Tiles.shadingMask.cgImage!
	private static let overlayOpacity: CGFloat = 0.5

	static func terrain(surface: TileSurface, variant: Tiles.Variant) -> SKTileGroup {
		let key = TerrainKey(surface: surface, variant: variant)
		if let group = terrainCache[key] { return group }
		let group = makeTerrain(image: surface.image(variant: variant)!)
		terrainCache[key] = group
		return group
	}

	static func terrain(_ terrain: Terrain, at xy: XY) -> SKTileGroup {
		self.terrain(surface: terrain.tileSurface, variant: xy.tileVariant)
	}

	static func decoration(_ terrain: Terrain, at xy: XY) -> SKTileGroup? {
		terrain.decoration(variant: xy.tileVariant).map { decoration in self.decoration(decoration) }
	}

	static func decoration(_ decoration: CGImage.Decoration) -> SKTileGroup {
		if let group = decorationCache[decoration] { return group }
		let group = make(image: .decoration(decoration))
		decorationCache[decoration] = group
		return group
	}

	static func overlay(_ overlay: TileOverlay) -> SKTileGroup {
		if let group = overlayCache[overlay] { return group }
		let group = self.overlay(color: overlay.color)
		overlayCache[overlay] = group
		return group
	}

	private static func makeTerrain(image: CGImage) -> SKTileGroup {
		make(image: ImageBuffer.tile.draw { ctx in
			ctx.drawTile(image)
			ctx.drawTile(.frame)
		})
	}

	private static func overlay(color: SKColor) -> SKTileGroup {
		make(image: ImageBuffer.tile.draw { ctx in
			ctx.drawTile(overlayMask)
			ctx.setBlendMode(.sourceIn)
			ctx.setFillColor(color.withAlphaComponent(overlayOpacity).cgColor)
			ctx.fill(CGRect(origin: .zero, size: .tile3D))
			ctx.setBlendMode(.normal)
		})
	}

	private static func make(image: CGImage) -> SKTileGroup {
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: texture.size()
			)
		)
	}
}

@MainActor
private extension CGImage {

	/// Stable tile-sized speckle, rendered once — noising a surface is then a
	/// single masked draw instead of a per-pixel fill on every texture build.
	static let noise = Tiles.Variant.allCases.map { variant in
		CGImage.draw(size: .tile3D) { ctx in
			drawNoise(in: ctx, grainSize: 1, maxOpacity: 0.033, seed: variant.rawValue * 2)
		}
	}

	static let strongNoise = Tiles.Variant.allCases.map { variant in
		CGImage.draw(size: .tile3D) { ctx in
			drawNoise(in: ctx, grainSize: 2, maxOpacity: 0.1, seed: variant.rawValue * 2 + 1)
			ctx.draw(noise[variant.rawValue], in: CGRect(origin: .zero, size: .tile3D))
		}
	}

	static let harshNoise = Tiles.Variant.allCases.map { variant in
		CGImage.draw(size: .tile3D) { ctx in
			drawNoise(in: ctx, grainSize: 4, maxOpacity: 0.15, seed: variant.rawValue + 8)
			ctx.draw(strongNoise[variant.rawValue], in: CGRect(origin: .zero, size: .tile3D))
		}
	}

	private static func drawNoise(in ctx: CGContext, grainSize: Int, maxOpacity: CGFloat, seed: Int) {
		var d20 = D20(seed: seed)
		for y in stride(from: 0, to: ctx.height, by: grainSize) {
			for x in stride(from: 0, to: ctx.width, by: grainSize) {
				ctx.setFillColor(UIColor.black.withAlphaComponent(CGFloat(d20.uniform()) * maxOpacity).cgColor)
				ctx.fill(CGRect(x: x, y: y, width: grainSize, height: grainSize))
			}
		}
	}

	/// Applies speckle only where the source image is nontransparent.
	func noised(with noise: CGImage) -> CGImage {
		.draw(size: CGSize(width: width, height: height)) { ctx in
			ctx.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
			ctx.setBlendMode(.sourceAtop)
			ctx.draw(noise, in: CGRect(origin: .zero, size: .tile3D))
			ctx.setBlendMode(.normal)
		}
	}
}

private extension CGContext {

	func drawTile(_ image: CGImage?) {
		guard let image else { return }
		draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
	}
}

@MainActor
extension SKTileSet {

	private static let decorated: [Terrain] = [
		.city, .airfield, .port, .bridgeWE, .bridgeSN, .fort,
		.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE,
		.roadTE, .roadTN, .roadTW, .roadTS, .roadX,
	]

	static let terrain = SKTileSet(
		tileGroups: TileSurface.allCases.flatMap { surface in
			Tiles.Variant.allCases.map { variant in
				.terrain(surface: surface, variant: variant)
			}
		},
		tileSetType: .isometric
	)

	static let decorations = SKTileSet(
		tileGroups: decorated.flatMap { terrain in
			(terrain == .city || terrain == .fort ? Tiles.Variant.allCases : [.first])
				.compactMap { variant in
					terrain.decoration(variant: variant)
						.map { decoration in .decoration(decoration) }
				}
		},
		tileSetType: .isometric
	)

	static let overlay = SKTileSet(
		tileGroups: TileOverlay.palette.map { .overlay($0) },
		tileSetType: .isometric
	)

	static let fog = SKTileSet(tileGroups: [.fog], tileSetType: .isometric)
}

extension SKTileMapNode {

	convenience init(tiles: SKTileSet, size: Int) {
		self.init(
			tileSet: tiles,
			columns: size,
			rows: size,
			tileSize: .tile
		)
	}

	func setTileGroup(_ tileGroup: SKTileGroup?, at xy: XY) {
		setTileGroup(tileGroup, forColumn: xy.x, row: xy.y)
	}
}

@MainActor
extension SKTexture {

	private static var tileCache: [Terrain: SKTexture] = [:]

	/// The terrain and decoration drawn into one texture for the editor palette.
	static func tile(_ terrain: Terrain) -> SKTexture {
		if let texture = tileCache[terrain] { return texture }
		let texture = SKTexture(cgImage: ImageBuffer.tile.draw { ctx in
			ctx.drawTile(terrain.tileSurface.image())
			ctx.drawTile(terrain.decoration().map(CGImage.decoration))
			ctx.drawTile(.frame)
		})
		texture.filteringMode = .nearest
		tileCache[terrain] = texture
		return texture
	}
}
