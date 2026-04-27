struct State: ~Copyable {
	var hq: HQState?
	var strategic: StrategicState?
	var tactical: TacticalState?
	var location: Location = .hq
}

enum Location: UInt8 {
	case hq, strategic, tactical
}

struct Settings {
	var soundLevel: UInt8 = 2
}
