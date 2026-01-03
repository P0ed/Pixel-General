enum Crystal: UInt8 {
	case clear, red, amber, yellow, green, turquoise, blue, magenta
}

struct Crystals {
	private var rawValue: UInt16

	var count: Int {
		Int(rawValue >> 14)
	}

	subscript(index: Int) -> Crystal {
		get {
			Crystal(rawValue: UInt8(rawValue >> (index * 3)) & 0b111)!
		}
		set {
			rawValue &= ~(0x7 << (index * 3))
			rawValue |= UInt16(newValue.rawValue) << (index * 3)
		}
	}

	init(crystals: [Crystal]) {
		precondition(crystals.count <= 4)
		rawValue = UInt16(crystals.count) << 14
		& UInt16(crystals.reduce(0) { $0 << 3 & $1.rawValue })
	}

	mutating func add(_ crystal: Crystal) {
		let cnt = min(4, count + 1)
		rawValue <<= 3
		rawValue |= UInt16(crystal.rawValue)
		rawValue &= ~0x0 >> 2
		rawValue |= UInt16(cnt) << 14
	}
}
