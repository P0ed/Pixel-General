import SpriteKit
import UIKit
import COR
import GFX

/// What the top face of a base tile shows. Mode-dependent: terrain colors,
/// political ownership, or supply level. Fog is baked into the base tile;
/// decorations are separate layers.
enum TileSurface: Hashable {
	case none, field, forest, rough, mountain, water, sea
	case team(Team)
	case country(Country)
	case supply(UInt8)

	var color: SKColor {
		switch self {
		case .none: .graySurface
		case .field: .fieldSurface
		case .forest: .forestSurface
		case .rough: .roughSurface
		case .mountain: .mountainSurface
		case .water: .waterSurface
		case .sea: .seaSurface
		case .team(let team): team.color
		case .country(let country): country.color
		case .supply(let level): .amberGreen8(level)
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
		case .none, .team, .country, .supply:
			return image
		}
	}
}

private extension XY {

	var tileVariant: Tiles.Variant {
		var d20 = D20(seed: x * 64 + y)
		let variants = Tiles.Variant.allCases
		return variants[Int(d20.next() % UInt64(variants.count))]
	}
}

extension Terrain {

	var tileSurface: TileSurface {
		switch self {
		case .forest: .forest
		case .rough: .rough
		case .mountain: .mountain
		case .river, .bridgeWE, .bridgeSN: .water
		case .sea: .sea
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

	static let gray = base(surface: .none)
	static let blue = base(surface: .team(.axis))
	static let yellow = base(surface: .team(.allies))
	static let red = base(surface: .team(.soviet))

	private struct BaseKey: Hashable {
		let surface: TileSurface
		let fog: Bool
		let variant: Tiles.Variant
	}
	private static var baseCache: [BaseKey: SKTileGroup] = [:]

	static func base(surface: TileSurface, fog: Bool = false, variant: Tiles.Variant = .first) -> SKTileGroup {
		let key = BaseKey(surface: surface, fog: fog, variant: variant)
		if let group = baseCache[key] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(surface.image(variant: variant))
				ctx.drawTile(.frame)
				if fog { ctx.dim() }
			}
		)
		baseCache[key] = group
		return group
	}

	static func base(terrain: Terrain, fog: Bool, at xy: XY) -> SKTileGroup {
		base(surface: terrain.tileSurface, fog: fog, variant: xy.tileVariant)
	}

	private struct DecorationKey: Hashable {
		let decoration: CGImage.Decoration
		let fog: Bool
	}
	private static var decorationCache: [DecorationKey: SKTileGroup] = [:]

	static func decoration(_ terrain: Terrain, fog: Bool, at xy: XY) -> SKTileGroup? {
		guard let decoration = terrain.decoration(variant: xy.tileVariant) else { return nil }
		return self.decoration(decoration, fog: fog)
	}

	static func decoration(_ decoration: CGImage.Decoration, fog: Bool) -> SKTileGroup {
		let key = DecorationKey(decoration: decoration, fog: fog)
		if let group = decorationCache[key] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(.decoration(decoration))
				if fog { ctx.dim() }
			}
		)
		decorationCache[key] = group
		return group
	}

	private static func make(image: CGImage) -> SKTileGroup {
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: .tile3D
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

	/// Halves RGB while keeping alpha: 50 % black over premultiplied pixels.
	func dim() {
		setBlendMode(.sourceAtop)
		setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
		fill(CGRect(origin: .zero, size: .tile3D))
		setBlendMode(.normal)
	}
}

@MainActor
extension SKTileSet {

	private static let decorated: [Terrain] = [
		.city, .airfield, .bridgeWE, .bridgeSN, .fort,
		.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE,
		.roadTE, .roadTN, .roadTW, .roadTS, .roadX,
	]

	static let terrain = SKTileSet(
		tileGroups: .make { ts in
			for fog in [false, true] {
				for surface in [TileSurface.field, .forest, .rough, .mountain, .water, .sea] {
					for variant in Tiles.Variant.allCases {
						ts.append(.base(surface: surface, fog: fog, variant: variant))
					}
				}
				for team in Team.allCases {
					ts.append(.base(surface: .team(team), fog: fog))
				}
				for level in 0 ... 7 as ClosedRange<UInt8> {
					ts.append(.base(surface: .supply(level), fog: fog))
				}
				for country in Country.allCases {
					ts.append(.base(surface: .country(country), fog: fog))
				}
			}
		},
		tileSetType: .isometric
	)

	static let decorations = SKTileSet(
		tileGroups: .make { ts in
			for terrain in decorated {
				let variants = terrain == .city || terrain == .fort ? Tiles.Variant.allCases : [.first]
				for variant in variants {
					guard let decoration = terrain.decoration(variant: variant) else { continue }
					ts.append(.decoration(decoration, fog: false))
					ts.append(.decoration(decoration, fog: true))
				}
			}
		},
		tileSetType: .isometric
	)

	static let colors = SKTileSet(
		tileGroups: [.gray, .blue, .yellow, .red],
		tileSetType: .isometric
	)
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

	/// `SKTileGroup.base` flattened into one texture, for the palette's icons.
	static func tile(_ terrain: Terrain) -> SKTexture {
		if let texture = tileCache[terrain] { return texture }
		let texture = SKTexture(cgImage: ImageBuffer.tile.draw { ctx in
			ctx.drawTile(terrain.tileSurface.image())
			ctx.drawTile(.frame)
			ctx.drawTile(terrain.decoration().map(CGImage.decoration))
		})
		texture.filteringMode = .nearest
		tileCache[terrain] = texture
		return texture
	}
}
