import SpriteKit
import GameplayKit
import UIKit
import COR

private let seaNoiseVariants: UInt8 = 8

/// What the top face of a base tile shows. Mode-dependent: terrain colors,
/// political ownership, or supply level. Decorations and fog are separate
/// layers, so adding a mode only adds surfaces here.
enum TileSurface: Hashable {
	case none, field, forest, water, sea
	case team(Team)
	case country(Country)
	case supply(UInt8)

	var color: SKColor {
		switch self {
		case .none: .graySurface
		case .field: .fieldSurface
		case .forest: .forestSurface
		case .water: .waterSurface
		case .sea: .seaSurface
		case .team(let team): team.color
		case .country(let country): country.color
		case .supply(let level): .redToGreen8(level)
		}
	}
}

extension Terrain {

	var tileSurface: TileSurface {
		switch self {
		case .forest, .forestHill: .forest
		case .river, .bridgeWE, .bridgeSN: .water
		case .sea: .sea
		default: .field
		}
	}

	var decoration: UIImage? {
		switch self {
		case .none, .river, .sea, .field, .forest, .hill, .forestHill, .mountain: nil
		case .city: .city
		case .airfield: .airfield
		case .bridgeWE: .bridgeWE
		case .bridgeSN: .bridgeSN
		case .roadNW: .roadNW
		case .roadNE: .roadNE
		case .roadWE: .roadWE
		case .roadSN: .roadSN
		case .roadSW: .roadSW
		case .roadSE: .roadSE
		case .villageE: .villageE
		case .villageN: .villageN
		case .villageW: .villageW
		case .villageS: .villageS
		case .roadX: .roadX
		case .fort: .fort
		}
	}
}

@MainActor
extension SKTileGroup {

	static let gray = base(surface: .none, elevation: 0)
	static let blue = base(surface: .team(.axis), elevation: 0)
	static let yellow = base(surface: .team(.allies), elevation: 0)
	static let red = base(surface: .team(.soviet), elevation: 0)

	private struct BaseKey: Hashable {
		let surface: TileSurface
		let elevation: Int
		let variant: UInt8
	}
	private static var baseCache: [BaseKey: SKTileGroup] = [:]

	static func base(surface: TileSurface, elevation: Int, variant: UInt8 = 0) -> SKTileGroup {
		let variant = surface == .sea ? variant % seaNoiseVariants : 0
		let key = BaseKey(surface: surface, elevation: elevation, variant: variant)
		if let group = baseCache[key] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(UIImage.frame(elevation).cg)
				let image = UIImage.surface(elevation).cg?.tinted(surface.color.cgColor)
				ctx.drawTile(surface == .sea ? image?.noised(seed: variant) : image)
			}
		)
		baseCache[key] = group
		return group
	}

	static func base(terrain: Terrain, at xy: XY) -> SKTileGroup {
		base(
			surface: terrain.tileSurface,
			elevation: terrain.elevationLevel,
			variant: terrain.isSea ? seaNoiseVariant(at: xy) : 0
		)
	}

	static func team(_ team: Team, elevation: Int) -> SKTileGroup {
		base(surface: .team(team), elevation: elevation)
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
				ctx.drawTile(image.cg)
				if fog { ctx.dim(.sourceAtop) }
			}
		)
		decorationCache[key] = group
		return group
	}

	private static var fogCache: [Int: SKTileGroup] = [:]

	static func fog(elevation: Int) -> SKTileGroup {
		if let group = fogCache[elevation] { return group }
		let group = make(
			image: ImageBuffer.tile.draw { ctx in
				ctx.drawTile(UIImage.frame(elevation).cg)
				ctx.drawTile(UIImage.surface(elevation).cg)
				ctx.dim(.sourceIn)
			}
		)
		fogCache[elevation] = group
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

private func seaNoiseVariant(at xy: XY) -> UInt8 {
	var hash = UInt32(truncatingIfNeeded: xy.x) &* 0x9E37_79B9
	hash ^= UInt32(truncatingIfNeeded: xy.y) &* 0x85EB_CA6B
	hash ^= hash >> 16
	return UInt8(hash % UInt32(seaNoiseVariants))
}

private extension CGImage {

	/// Applies stable white noise only where the source image is nontransparent.
	func noised(seed: UInt8) -> CGImage {
		.draw(size: CGSize(width: width, height: height)) { ctx in
			let bounds = CGRect(x: 0, y: 0, width: width, height: height)
			ctx.draw(self, in: bounds)
			ctx.setBlendMode(.sourceAtop)

			for y in 0 ..< height {
				for x in 0 ..< width {
					var sample = UInt32(truncatingIfNeeded: y * width + x)
					sample &+= UInt32(seed) &* 0x9E37_79B9
					sample = (sample ^ (sample >> 16)) &* 0x7FEB_352D
					sample = (sample ^ (sample >> 15)) &* 0x846C_A68B
					sample ^= sample >> 16

					let value = CGFloat(sample >> 24) / 255.0 * 2.0 - 1.0
					ctx.setFillColor(UIColor.black.withAlphaComponent(abs(value) * 0.1).cgColor)
					ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
				}
			}
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
	/// `.sourceIn` shapes a standalone overlay, `.sourceAtop` dims in place.
	func dim(_ mode: CGBlendMode) {
		setBlendMode(mode)
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
			for elevation in 0 ... 2 {
				for surface in [TileSurface.field, .forest, .water] {
					ts.append(.base(surface: surface, elevation: elevation))
				}
				for variant in 0 ..< seaNoiseVariants {
					ts.append(.base(surface: .sea, elevation: elevation, variant: variant))
				}
				for team in Team.allCases {
					ts.append(.team(team, elevation: elevation))
				}
				for level in 0 ... 7 as ClosedRange<UInt8> {
					ts.append(.base(surface: .supply(level), elevation: elevation))
				}
				for country in Country.allCases {
					ts.append(.base(surface: .country(country), elevation: elevation))
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

	static let fog = SKTileSet(
		tileGroups: (0 ... 2).map { .fog(elevation: $0) },
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

extension UIImage {

	@MainActor
	static func tile(_ terrain: Terrain) -> UIImage {
		let elevation = terrain.elevationLevel
		let image = ImageBuffer.tile.draw { ctx in
			ctx.drawTile(UIImage.frame(elevation).cg)
			let surface = UIImage.surface(elevation).cg?.tinted(terrain.tileSurface.color.cgColor)
			ctx.drawTile(terrain.isSea ? surface?.noised(seed: 0) : surface)
			ctx.drawTile(terrain.decoration?.cg)
		}
		return UIImage(cgImage: image)
	}

	static func frame(_ elevation: Int) -> UIImage {
		switch elevation {
		case 0: .frame0
		case 1: .frame1
		default: .frame2
		}
	}

	static func surface(_ elevation: Int) -> UIImage {
		switch elevation {
		case 0: .surface0
		case 1: .surface1
		default: .surface2
		}
	}
}
