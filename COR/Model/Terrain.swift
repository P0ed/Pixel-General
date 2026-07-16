@frozen public enum Terrain: UInt8, Hashable, Codable, Sendable {
	case none
	case river
	case bridgeWE, bridgeSN
	case field, forest, hill, forestHill, mountain
	case city, airfield
	case villageE, villageN, villageW, villageS
	case roadNW, roadNE, roadWE, roadSN, roadSW, roadSE, roadX
	case fort
	case sea
}

public extension Terrain {

	var elevationLevel: Int {
		switch self {
		case .hill, .forestHill: 1
		case .mountain: 2
		default: 0
		}
	}

	var isBridgable: Bool {
		switch self {
		case .field, .forest, .city, .airfield: true
		case .villageE, .villageN, .villageW, .villageS: true
		case .roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE, .roadX: true
		default: false
		}
	}

	var isSettlement: Bool {
		switch self {
		case .city, .airfield, .villageE, .villageN, .villageW, .villageS: true
		default: false
		}
	}

	var isVillage: Bool {
		switch self {
		case .villageE, .villageN, .villageW, .villageS: true
		default: false
		}
	}

	var isNoFlyZone: Bool {
		switch self {
		case .city, .villageE, .villageN, .villageW, .villageS: true
		default: false
		}
	}

	var isRoad: Bool {
		switch self {
		case .roadNE, .roadNW, .roadSE, .roadSN, .roadSW, .roadWE, .roadX: true
		default: false
		}
	}

	var hasRoad: Bool {
		isRoad || isBridge || isSettlement
	}

	var isBridge: Bool {
		switch self {
		case .bridgeWE, .bridgeSN: true
		default: false
		}
	}

	var isRiver: Bool { self == .river }
	var isSea: Bool { self == .sea }
	var isWater: Bool { isRiver || isSea }

	var isHighground: Bool {
		switch self {
		case .hill, .forestHill, .mountain: true
		default: false
		}
	}

	func moveCost(_ stats: Unit) -> UInt8 {
		switch stats.type.moveType {
		case .leg:
			switch self {
			case _ where hasRoad: 1
			case .field, .fort: 1
			case .forest, .hill: min(stats.mov, 2)
			case .forestHill: min(stats.mov, 3)
			case .mountain: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .wheel:
			switch self {
			case _ where hasRoad: 1
			case .field: 2
			case .forest, .hill, .fort: 3
			case .forestHill: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .track:
			switch self {
			case _ where hasRoad: 1
			case .field: 1
			case .forest, .hill, .fort: 2
			case .forestHill: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .air:
			self.isNoFlyZone ? 0x10 : 1
		case .naval:
			self == .sea ? 1 : 0x10
		}
	}

	var baseEntrenchment: UInt8 {
		switch self {
		case .field: 0
		case .hill, .airfield: 1
		case .forest, .forestHill, .mountain, .villageE, .villageN, .villageW, .villageS: 2
		case .city, .fort: 3
		default: 0
		}
	}

	func closeCombat(_ type: UnitType) -> Int8 {
		guard type.targetType == .hard else { return 0 }
		let penalty: Int8 = type == .heavyTrack ? -2 : -1
		return switch self {
		case .hill, .airfield: penalty * 1
		case .forest, .villageE, .villageN, .villageW, .villageS: penalty * 2
		case .city, .mountain, .forestHill, .fort: penalty * 3
		default: 0
		}
	}

	func def(_ type: UnitType) -> Int8 {
		switch self {
		case _ where type == .heli || type == .fighter || type == .cas: 0
		case _ where isRoad: -1
		case _ where isBridge: -2
		case _ where isRiver:
			switch type {
			case .inf, .art, .aa, .supply, .wheelArt, .wheelAA: -2
			case .lightWheel, .lightTrack, .trackAA, .trackArt: -3
			case .heavyTrack: -5
			default: 0
			}
		case .hill, .airfield:
			switch type {
			case .inf, .art, .aa: 1
			case .supply, .wheelArt, .wheelAA: 1
			case .trackAA, .trackArt: 1
			default: 0
			}
		case .forest, .villageE, .villageN, .villageW, .villageS:
			switch type {
			case .inf, .art, .aa: 2
			case .supply, .wheelArt, .wheelAA: 1
			case .trackAA, .trackArt: 1
			default: 0
			}
		case .city, .mountain, .forestHill, .fort:
			switch type {
			case .inf, .art, .aa: 3
			case .supply, .wheelArt, .wheelAA: 2
			case .trackAA, .trackArt: 1
			default: 0
			}
		default: 0
		}
	}
}
