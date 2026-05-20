enum Terrain: UInt8, Hashable, Codable {
	case none
	case water, river00, river01, river10, river11
	case bridge01, bridge10
	case field, forest, hill, forestHill, mountain
	case city, airfield
	case roadNW, roadNE, roadWE, roadSN, roadSW, roadSE
	case roadNWE, roadSWE, roadSEN, roadSWN, roadNWSE
}

extension Terrain {

	var isBridgable: Bool {
		switch self {
		case .airfield, .city, .field, .forest: true
		default: false
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
				.roadNWE, .roadSEN, .roadSWE, .roadSWN, .roadNWSE,
				.bridge01, .bridge10: true
		default: false
		}
	}

	var isBridge: Bool {
		switch self {
		case .bridge01, .bridge10: true
		default: false
		}
	}

	var isRiver: Bool {
		switch self {
		case .river00, .river01, .river10, .river11: true
		default: false
		}
	}

	var isHighground: Bool {
		switch self {
		case .hill, .forestHill, .mountain: true
		default: false
		}
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

	var baseEntrenchment: UInt8 {
		switch self {
		case .field: 0
		case .hill, .airfield, .roadNWE, .roadSEN, .roadSWE, .roadSWN: 1
		case .forest, .forestHill, .mountain, .roadNWSE: 2
		case .city: 3
		default: 0
		}
	}

	func closeCombat(_ type: UnitType) -> Int8 {
		switch self {
		case .hill, .airfield, .roadNWE, .roadSEN, .roadSWE, .roadSWN:
			switch type {
			case .lightWheel, .lightTrack: -1
			case .heavyTrack: -2
			default: 0
			}
		case .forest, .roadNWSE:
			switch type {
			case .lightWheel, .lightTrack: -2
			case .heavyTrack: -4
			default: 0
			}
		case .city, .mountain, .forestHill:
			switch type {
			case .lightWheel, .lightTrack: -3
			case .heavyTrack: -6
			default: 0
			}
		default: 0
		}
	}

	func def(_ type: UnitType) -> Int8 {
		switch self {
		case _ where type == .heli || type == .jet: 0
		case _ where isRoad: -1
		case _ where isBridge: -2
		case _ where isRiver:
			switch type {
			case .soft, .softWheel: -2
			case .lightWheel, .lightTrack: -3
			case .heavyTrack: -5
			default: 0
			}
		case .hill, .airfield, .roadNWE, .roadSEN, .roadSWE, .roadSWN:
			switch type {
			case .soft: 1
			case .lightWheel, .lightTrack: -1
			case .heavyTrack: -2
			default: 0
			}
		case .forest, .roadNWSE:
			switch type {
			case .soft: 2
			case .lightWheel, .lightTrack: -2
			case .heavyTrack: -4
			default: 0
			}
		case .city, .mountain, .forestHill:
			switch type {
			case .soft: 3
			case .lightWheel, .lightTrack: -3
			case .heavyTrack: -6
			default: 0
			}
		default: 0
		}
	}
}
