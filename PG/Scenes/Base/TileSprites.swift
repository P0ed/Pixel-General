import SpriteKit
import GameplayKit

extension SKTileGroup {

	private static func make(_ image: NSImage) -> SKTileGroup {
		SKTileGroup(
			tileDefinition: SKTileDefinition(
				texture: .init(image: image),
				size: image.size
			)
		)
	}

	static let city = make(.city)
	static let field = make(.field)
	static let forest = make(.forest)
	static let forestHill = make(.forestHill)
	static let hill = make(.hill)
	static let mountain = make(.mountain)

	static let river00 = make(.river00)
	static let river01 = make(.river01)
	static let river10 = make(.river10)
	static let river11 = make(.river11)

	static let cityFog = make(.cityFog)
	static let fieldFog = make(.fieldFog)
	static let forestFog = make(.forestFog)
	static let forestHillFog = make(.forestHillFog)
	static let hillFog = make(.hillFog)
	static let mountainFog = make(.mountainFog)

	static let river00Fog = make(.river00Fog)
	static let river01Fog = make(.river01Fog)
	static let river10Fog = make(.river10Fog)
	static let river11Fog = make(.river11Fog)
}

extension Terrain {

	func tileGroup(fog: Bool) -> SKTileGroup? {
		if fog {
			switch self {
			case .field: .field
			case .forest: .forest
			case .hill: .hill
			case .forestHill: .forestHill
			case .mountain: .mountain
			case .city: .city
			case .river: .river00
			case .none: .none
			}
		} else {
			switch self {
			case .field: .fieldFog
			case .forest: .forestFog
			case .hill: .hillFog
			case .forestHill: .forestHillFog
			case .mountain: .mountainFog
			case .city: .cityFog
			case .river: .river00Fog
			case .none: .none
			}
		}
	}
}

extension SKTileSet {

	static let terrain = SKTileSet(
		tileGroups: [
			.city, .field, .forest, .hill, .forestHill, .mountain,
			.river00, .river01, .river10, .river10,
			.cityFog, .fieldFog, .forestFog, .hillFog, .forestHillFog, .mountainFog,
			.river00Fog, .river01Fog, .river10Fog, .river11Fog,
		],
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
