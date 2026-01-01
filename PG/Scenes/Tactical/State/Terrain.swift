import CoreGraphics

enum Terrain: UInt8, Hashable, Codable {
	case none, river, field, forest, hill, forestHill, mountain, city
}

extension Terrain {

	func moveCost(_ stats: Stats) -> UInt8 {
		switch stats.moveType {
		case .leg: switch self {
		case .field, .city: 1
		case .forest, .hill: min(stats.mov, 2)
		case .forestHill: min(stats.mov, 3)
		case .river: stats.mov
		case .mountain: stats.unitType == .fighter && stats.moveType == .leg ? stats.mov : 0x10
		case .none: 0x10
		}
		case .wheel: switch self {
		case .city: 1
		case .field: 2
		case .forest, .hill: 3
		case .forestHill, .river: stats.mov
		case .none, .mountain: 0x10
		}
		case .track: switch self {
		case .field, .city: 1
		case .forest, .hill: 2
		case .forestHill, .river: stats.mov
		case .none, .mountain: 0x10
		}
		case .air: 1
		}
	}

	var defBonus: Int {
		switch self {
		case .forest, .hill: 1
		case .forestHill, .mountain, .city: 2
		case .field, .none: 0
		case .river: -1
		}
	}

	var elevation: CGFloat {
		switch self {
		case .hill, .forestHill: 4.0
		case .mountain: 8.0
		default: 0.0
		}
	}
}

extension Map<Terrain> {

	func point(at xy: XY) -> CGPoint {
		xy.point + CGPoint(x: 0, y: self[xy].elevation)
	}
}
