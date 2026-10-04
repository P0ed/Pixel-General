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
	var image: CGImage? {
		let image = CGImage.surface.tinted(color.cgColor)
		switch self {
		case .field, .forest, .rough, .mountain, .water, .sea:
			return image?.noised()
		case .none, .team, .country, .supply:
			return image
		}
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

	/// Compass names map onto GFX axes the way `XY.pt` puts them on screen:
	/// E is `xPlus`, N `yMinus`, W `xMinus`, S `yPlus`.
	@MainActor
	var decoration: CGImage? {
		switch self {
		case .none, .river, .sea, .field, .forest, .rough, .mountain: nil
		case .city: .decoration(.city)
		case .fort: .decoration(.fort)
		case .airfield: .decoration(.airfield)
		case .villageE: .decoration(.village(.xPlus))
		case .villageN: .decoration(.village(.yMinus))
		case .villageW: .decoration(.village(.xMinus))
		case .villageS: .decoration(.village(.yPlus))
		case .bridgeWE: .decoration(.bridge(.x))
		case .bridgeSN: .decoration(.bridge(.y))
		case .roadNW: .decoration(.road([.yMinus, .xMinus]))
		case .roadNE: .decoration(.road([.yMinus, .xPlus]))
		case .roadWE: .decoration(.road([.xMinus, .xPlus]))
		case .roadSN: .decoration(.road([.yPlus, .yMinus]))
		case .roadSW: .decoration(.road([.yPlus, .xMinus]))
		case .roadSE: .decoration(.road([.yPlus, .xPlus]))
		case .roadX: .decoration(.road([.xPlus, .xMinus, .yPlus, .yMinus]))
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
	}
	private static var baseCache: [BaseKey: SKTileGroup] = [:]

	static func base(surface: TileSurface, fog: Bool = false) -> SKTileGroup {
		let key = BaseKey(surface: surface, fog: fog)
		if let group = baseCache[key] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(surface.image)
				ctx.drawTile(.frame)
				if fog { ctx.dim() }
			}
		)
		baseCache[key] = group
		return group
	}

	static func base(terrain: Terrain, fog: Bool = false) -> SKTileGroup {
		base(surface: terrain.tileSurface, fog: fog)
	}

	private struct DecorationKey: Hashable {
		let terrain: Terrain
		let fog: Bool
	}
	private static var decorationCache: [DecorationKey: SKTileGroup] = [:]

	static func decoration(_ terrain: Terrain, fog: Bool) -> SKTileGroup? {
		guard let image = terrain.decoration else { return nil }
		let key = DecorationKey(terrain: terrain, fog: fog)
		if let group = decorationCache[key] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(image)
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
	static let noise: CGImage = .draw(size: .tile3D) { ctx in
		var d20 = D20()
		for y in 0 ..< Int(CGSize.tile3D.height) {
			for x in 0 ..< Int(CGSize.tile3D.width) {
				ctx.setFillColor(UIColor.black.withAlphaComponent(CGFloat(d20.uniform()) * 0.033).cgColor)
				ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
			}
		}
	}

	/// Applies stable white noise only where the source image is nontransparent.
	func noised() -> CGImage {
		.draw(size: CGSize(width: width, height: height)) { ctx in
			ctx.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
			ctx.setBlendMode(.sourceAtop)
			ctx.draw(CGImage.noise, in: CGRect(origin: .zero, size: .tile3D))
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
		.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE, .roadX,
		.villageE, .villageN, .villageW, .villageS,
	]

	static let terrain = SKTileSet(
		tileGroups: .make { ts in
			for fog in [false, true] {
				for surface in [TileSurface.field, .forest, .rough, .mountain, .water, .sea] {
					ts.append(.base(surface: surface, fog: fog))
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
			decorated.forEach { terrain in
				ts.append(.decoration(terrain, fog: false)!)
				ts.append(.decoration(terrain, fog: true)!)
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
			ctx.drawTile(terrain.tileSurface.image)
			ctx.drawTile(.frame)
			ctx.drawTile(terrain.decoration)
		})
		texture.filteringMode = .nearest
		tileCache[terrain] = texture
		return texture
	}
}
