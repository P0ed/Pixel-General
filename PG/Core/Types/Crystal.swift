enum Crystal: UInt8 {
	case red, amber, turquoise, blue
}

struct Crystals {
	var rawValue: UInt8
}

extension Crystals {

	subscript(index: Int) -> Crystal {
		get {
			Crystal(rawValue: UInt8(rawValue >> (index * 2)) & 0b11)!
		}
		set {
			rawValue &= ~(0b11 << (index * 2))
			rawValue |= newValue.rawValue << (index * 2)
		}
	}

	static var empty: Self {
		.init(rawValue: 0)
	}

	init(crystals: [Crystal]) {
		rawValue = UInt8(crystals.reduce(0) { $0 << 2 & $1.rawValue })
	}

	mutating func add(_ crystal: Crystal) {
		rawValue <<= 2
		rawValue |= crystal.rawValue
	}
}
