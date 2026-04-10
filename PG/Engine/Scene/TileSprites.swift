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
	static let airfield = make(.airfield)

	static let roadSN = make(.roadSn)
	static let roadSE = make(.roadSe)
	static let roadSW = make(.roadSw)
	static let roadNE = make(.roadNe)
	static let roadNW = make(.roadNw)
	static let roadWE = make(.roadWe)

	static let roadNWE = make(.roadNwe)
	static let roadSEN = make(.roadSen)
	static let roadSWE = make(.roadSwe)
	static let roadSWN = make(.roadSwn)

	static let roadNWSE = make(.roadNwse)

	static let field = make(.field)
	static let forest = make(.forest)
	static let forestHill = make(.forestHill)
	static let hill = make(.hill)
	static let mountain = make(.mountain)

	static let water = make(.water)
	static let river00 = make(.river00)
	static let river01 = make(.river01)
	static let river10 = make(.river10)
	static let river11 = make(.river11)
	static let bridge01 = make(.bridge01)
	static let bridge10 = make(.bridge10)

	static let cityFog = make(.cityFog)
	static let airfieldFog = make(.airfieldFog)

	static let roadSNFog = make(.roadSnFog)
	static let roadSEFog = make(.roadSeFog)
	static let roadSWFog = make(.roadSwFog)
	static let roadNEFog = make(.roadNeFog)
	static let roadNWFog = make(.roadNwFog)
	static let roadWEFog = make(.roadWeFog)

	static let roadNWEFog = make(.roadNweFog)
	static let roadSENFog = make(.roadSenFog)
	static let roadSWEFog = make(.roadSweFog)
	static let roadSWNFog = make(.roadSwnFog)

	static let roadNWSEFog = make(.roadNwseFog)

	static let fieldFog = make(.fieldFog)
	static let forestFog = make(.forestFog)
	static let forestHillFog = make(.forestHillFog)
	static let hillFog = make(.hillFog)
	static let mountainFog = make(.mountainFog)

	static let waterFog = make(.waterFog)
	static let river00Fog = make(.river00Fog)
	static let river01Fog = make(.river01Fog)
	static let river10Fog = make(.river10Fog)
	static let river11Fog = make(.river11Fog)
	static let bridge01Fog = make(.bridge01Fog)
	static let bridge10Fog = make(.bridge10Fog)
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
			case .airfield: .airfield
			case .water: .water
			case .river00: .river00
			case .river01: .river01
			case .river10: .river10
			case .river11: .river11
			case .bridge01: .bridge01
			case .bridge10: .bridge10
			case .roadNW: .roadNW
			case .roadNE: .roadNE
			case .roadWE: .roadWE
			case .roadSN: .roadSN
			case .roadSW: .roadSW
			case .roadSE: .roadSE
			case .roadNWE: .roadNWE
			case .roadSWE: .roadSWE
			case .roadSEN: .roadSEN
			case .roadSWN: .roadSWN
			case .roadNWSE: .roadNWSE
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
			case .airfield: .airfieldFog
			case .water: .waterFog
			case .river00: .river00Fog
			case .river01: .river01Fog
			case .river10: .river10Fog
			case .river11: .river11Fog
			case .bridge01: .bridge01Fog
			case .bridge10: .bridge10Fog
			case .roadNW: .roadNWFog
			case .roadNE: .roadNEFog
			case .roadWE: .roadWEFog
			case .roadSN: .roadSNFog
			case .roadSW: .roadSWFog
			case .roadSE: .roadSEFog
			case .roadNWE: .roadNWEFog
			case .roadSWE: .roadSWEFog
			case .roadSEN: .roadSENFog
			case .roadSWN: .roadSWNFog
			case .roadNWSE: .roadNWSEFog
			case .none: .none
			}
		}
	}
}

extension SKTileSet {

	static let terrain = SKTileSet(
		tileGroups: [
			.city, .airfield, .field, .forest,
			.roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE,
			.roadNWE, .roadSWE, .roadSEN, .roadSWN, .roadNWSE,
			.roadNWFog, .roadNEFog, .roadWEFog, .roadSNFog, .roadSWFog, .roadSEFog,
			.roadNWEFog, .roadSWEFog, .roadSENFog, .roadSWNFog, .roadNWSEFog,
			.hill, .forestHill, .mountain,
			.river00, .river01, .river10, .river11, .bridge01, .bridge10,
			.cityFog, .airfieldFog, .fieldFog, .forestFog,
			.hillFog, .forestHillFog, .mountainFog,
			.river00Fog, .river01Fog, .river10Fog, .river11Fog, .bridge01Fog, .bridge10Fog,
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
