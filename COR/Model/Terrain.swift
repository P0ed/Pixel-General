@frozen public enum Terrain: UInt8, Hashable, Codable, Sendable {
	case none
	case river
	case bridgeWE, bridgeSN
	case field, forest, rough, mountain
	case city, airfield
	case roadTE, roadTN, roadTW, roadTS
	case roadNW, roadNE, roadWE, roadSN, roadSW, roadSE, roadX
	case fort
	case sea
	case port
}

public extension Terrain {

	var isBridgable: Bool {
		switch self {
		case .field, .forest, .city: true
		default: isRoad
		}
	}

	var isSettlement: Bool {
		switch self {
		case .city, .airfield, .port: true
		default: false
		}
	}

	var isRoad: Bool {
		switch self {
		case .roadNE, .roadNW, .roadSE, .roadSN, .roadSW, .roadWE,
			.roadTE, .roadTN, .roadTW, .roadTS, .roadX: true
		default: false
		}
	}

	var hasRoad: Bool {
		isRoad || isBridge || self == .city
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
		case .rough, .mountain: true
		default: false
		}
	}

	func moveCost(_ stats: Unit) -> UInt8 {
		switch stats.type.moveType {
		case .leg:
			switch self {
			case _ where hasRoad: 1
			case .field, .fort, .airfield, .port: 1
			case .forest, .rough: min(stats.mov, 2)
			case .mountain: stats.mov
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .wheel:
			switch self {
			case _ where hasRoad: 1
			case .airfield, .port: 1
			case .field: 2
			case .forest, .rough, .fort: 3
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .track:
			switch self {
			case _ where hasRoad: 1
			case .field, .airfield, .port: 1
			case .forest, .rough, .fort: 2
			case _ where isRiver: stats.mov
			default: 0x10
			}
		case .air: 1
		case .naval: self == .sea || self == .port ? 1 : 0x10
		}
	}

	var baseEntrenchment: UInt8 {
		switch self {
		case .field: 0
		case .rough, .airfield: 1
		case .forest, .mountain: 2
		case .city, .fort: 3
		default: 0
		}
	}

	func closeCombat(_ type: UnitType) -> Int8 {
		guard type.targetType == .hard else { return 0 }
		let penalty: Int8 = type == .heavyTrack ? -2 : -1
		return switch self {
		case .rough, .airfield: penalty * 1
		case .forest: penalty * 2
		case .city, .mountain, .fort: penalty * 3
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
		case .rough, .airfield:
			switch type {
			case .inf, .art, .aa: 1
			case .supply, .wheelArt, .wheelAA: 1
			case .trackAA, .trackArt: 1
			default: 0
			}
		case .forest:
			switch type {
			case .inf, .art, .aa: 2
			case .supply, .wheelArt, .wheelAA: 1
			case .trackAA, .trackArt: 1
			default: 0
			}
		case .city, .mountain, .fort:
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
