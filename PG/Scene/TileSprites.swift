import SpriteKit
import GameplayKit
import UIKit
import COR

@MainActor
extension SKTileGroup {

	static let gray = make(color: .graySurface)
	static let blue = make(color: .blueSurface)
	static let yellow = make(color: .yellowSurface)
	static let green = make(color: .greenSurface)
	static let red = make(color: .redSurface)

	private static func make(_ image: UIImage) -> SKTileGroup {
		let texture = SKTexture(image: image)
		texture.filteringMode = .nearest

		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: image.size
			)
		)
	}

	private struct PoliticalKey: Hashable {
		let playerIndex: Int
		let elevation: Int
		let fog: Bool
	}
	private static var politicalCache: [PoliticalKey: SKTileGroup] = [:]

	static func political(playerIndex: Int, elevation: Int, fog: Bool) -> SKTileGroup {
		let key = PoliticalKey(playerIndex: playerIndex, elevation: elevation, fog: fog)
		if let g = politicalCache[key] { return g }
		let color: SKColor = switch playerIndex {
		case 0: .blueSurface
		case 1: .yellowSurface
		case 2: .greenSurface
		case 3: .redSurface
		default: .graySurface
		}
		let g = make(color: color, elevation: elevation, fog: fog)
		politicalCache[key] = g
		return g
	}

	static func make(
		color: SKColor,
		elevation: Int = 0,
		fog: Bool = false,
		decoration: UIImage? = nil
	) -> SKTileGroup {
		let frame = UIImage.frame(elevation)
		let surface = UIImage.surface(elevation)
		let image = composite(
			frame: frame,
			surface: surface,
			tint: color,
			decoration: decoration,
			fog: fog
		)
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: texture,
				size: frame.size
			)
		)
	}
}

@MainActor
extension SKTileGroup {

	private struct CacheKey: Hashable {
		let terrain: Terrain
		let fog: Bool
	}

	private static var cache: [CacheKey: SKTileGroup] = [:]

	static func tileGroup(terrain: Terrain, fog: Bool) -> SKTileGroup {
		let key = CacheKey(terrain: terrain, fog: fog)
		if let group = Self.cache[key] { return group }
		let group = SKTileGroup.make(
			color: terrain.surfaceColor,
			elevation: terrain.elevationLevel,
			fog: fog,
			decoration: terrain.decoration
		)
		Self.cache[key] = group
		return group
	}
}

extension Terrain {

	var surfaceColor: SKColor {
		switch self {
		case .forest, .forestHill: .forestSurface
		case .water, .bridgeWE, .bridgeSN: .waterSurface
		default: .fieldSurface
		}
	}

	var decoration: UIImage? {
		switch self {
		case .none, .water, .field, .forest, .hill, .forestHill, .mountain: nil
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
		}
	}
}

@MainActor
extension SKTileSet {

	private static let tiles: [Terrain] = [
		.city, .airfield, .field, .forest, .hill, .forestHill, .mountain,
		.water, .bridgeWE, .bridgeSN,
		.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE,
		.villageE, .villageN, .villageW, .villageS, .roadX,
	]

	static let terrain = SKTileSet(
		tileGroups: .make { ts in
			tiles.forEach { terrain in
				ts.append(.tileGroup(terrain: terrain, fog: false))
				ts.append(.tileGroup(terrain: terrain, fog: true))
			}
			ts += politicalTiles
		},
		tileSetType: .isometric
	)

	private static var politicalTiles: [SKTileGroup] {
		.make { out in
			for idx in -1 ... 3 {
				for elevation in 0 ... 2 {
					for fog in [false, true] {
						out.append(.political(playerIndex: idx, elevation: elevation, fog: fog))
					}
				}
			}
		}
	}

	static let colors = SKTileSet(
		tileGroups: [.gray, .blue, .yellow, .green, .red],
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

@MainActor
private func composite(
	frame: UIImage,
	surface: UIImage,
	tint: SKColor,
	decoration: UIImage?,
	fog: Bool
) -> CGImage {
	.draw(size: frame.size) { context in
		if let cg = frame.cg {
			context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
		}
		if let cg = surface.cg?.tinted(tint.cgColor) {
			context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
		}
		if let cg = decoration?.cg {
			context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
		}
		if fog {
			let count = context.bytesPerRow * context.height
			let px = unsafe context.data?.bindMemory(to: UInt8.self, capacity: count)
			for i in stride(from: 0, to: count, by: 4) {
				unsafe px?[i + 0] >>= 1
				unsafe px?[i + 1] >>= 1
				unsafe px?[i + 2] >>= 1
			}
		}
	}
}
