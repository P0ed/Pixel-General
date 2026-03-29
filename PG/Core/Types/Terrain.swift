import CoreGraphics

enum Terrain: UInt8, Hashable, Codable {
	case none
	case river00, river01, river10, river11
	case field, forest, hill, forestHill, mountain
	case city, airfield
	case roadNW, roadNE, roadWE, roadSN, roadSW, roadSE
	case roadNWE, roadSWE, roadSEN, roadSWN, roadNWSE
}

extension Terrain {

	var elevation: CGFloat {
		switch self {
		case .hill, .forestHill: 4.0
		case .mountain: 8.0
		default: 0.0
		}
	}

	var isBuilding: Bool {
		switch self {
		case .city, .airfield: true
		default: false
		}
	}

	var isRoad: Bool {
		switch self {
		case .roadNE, .roadNW, .roadSE, .roadSN, .roadSW, .roadWE,
				.roadNWE, .roadSEN, .roadSWE, .roadSWN, .roadNWSE: true
		default: false
		}
	}

	var isRiver: Bool {
		switch self {
		case .river00, .river01, .river10, .river11: true
		default: false
		}
	}
}

extension Map<Terrain> {

	func point(at xy: XY) -> CGPoint {
		xy.point + CGPoint(x: 0, y: self[xy].elevation)
	}
}

extension Terrain {

	func moveCost(_ stats: Unit) -> UInt8 {
		switch stats.type {
		case .soft:
			switch self {
			case _ where isRoad: 1
			case .field, .city, .airfield: 1
			case .forest, .hill: min(stats.mov, 2)
			case .forestHill: min(stats.mov, 3)
			case .mountain: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .softWheel, .lightWheel:
			switch self {
			case _ where isRoad: 1
			case .city, .airfield: 1
			case .field: 2
			case .forest, .hill: 3
			case .forestHill: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .lightTrack, .heavyTrack:
			switch self {
			case _ where isRoad: 1
			case .field, .city, .airfield: 1
			case .forest, .hill: 2
			case .forestHill: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .heli, .jet: 1
		}
	}

	var def: Int {
		switch self {
		case .field: 0
		case .forest, .hill, .airfield: 2
		case .forestHill, .city: 3
		case .mountain: 4
		case _ where isRoad: -1
		case _ where isRiver: -3
		default: 0
		}
	}

	func closeCombatPenalty(_ type: UnitType) -> Int {
		let def = max(0, def)
		return switch type {
		case .lightWheel, .lightTrack: -Int(def)
		case .heavyTrack: -Int(def * 2)
		default: 0
		}
	}
}
