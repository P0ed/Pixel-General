struct Player: DeadOrAlive {
	var country: Country
	var ai: Bool = false
	var alive: Bool = true
	var prestige: UInt16 = 0x300
	var crystals: Crystals = .empty
	var visible: SetXY = .empty
}

enum Country: UInt8, Hashable {
	case ind, irn, isr, ned, pak, rus, swe, ukr, usa

	static var zero: Self { .init(rawValue: 0)! }
}

enum Team: UInt8, Hashable {
	case axis, allies, soviet
}

extension Country {

	var team: Team {
		switch self {
		case .ned, .swe, .ukr: .axis
		case .isr, .pak, .usa: .allies
		case .ind, .irn, .rus: .soviet
		}
	}
}

extension Player {

	static var none: Self {
		.init(country: .ind, alive: false)
	}
}
