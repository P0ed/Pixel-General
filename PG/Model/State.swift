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
	var soundLevel: UInt8 = 1
}

extension Settings {

	mutating func toggleSound() {
		soundLevel = (soundLevel + 1) % 3
	}

	var outputVolume: Float {
		switch soundLevel {
		case 0: 0.0
		case 1: 0.3
		default: 1.0
		}
	}
}
