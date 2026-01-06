import CoreGraphics

enum Terrain: UInt8, Hashable, Codable {
	case none, river, field, forest, hill, forestHill, mountain, city
}

extension Terrain {

	func moveCost(_ stats: Stats) -> UInt8 {
		switch stats.type {
		case .soft:
			switch self {
			case .field, .city: 1
			case .forest, .hill: min(stats.mov, 2)
			case .forestHill: min(stats.mov, 3)
			case .river: stats.mov
			case .mountain: stats.mov
			case .none: 0x10
			}
		case .softWheel, .lightWheel, .mediumWheel:
			switch self {
			case .city: 1
			case .field: 2
			case .forest, .hill: 3
			case .forestHill, .river: stats.mov
			case .none, .mountain: 0x10
			}
		case .lightTrack, .mediumTrack, .heavyTrack:
			switch self {
			case .field, .city: 1
			case .forest, .hill: 2
			case .forestHill, .river: stats.mov
			case .none, .mountain: 0x10
			}
		case .air: 1
		}
	}

	var def: Int {
		switch self {
		case .forest, .hill: 1
		case .forestHill, .city: 2
		case .mountain: 3
		case .field, .none: 0
		case .river: -2
		}
	}

	func closeCombatPenalty(_ type: UnitType) -> Int {
		let def = max(0, def)
		return switch type {
		case .lightWheel, .lightTrack: -Int(def)
		case .mediumWheel, .mediumTrack: -Int(def * 2)
		case .heavyTrack: -Int(def * 3)
		default: 0
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
