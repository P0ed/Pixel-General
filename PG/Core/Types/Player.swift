struct Player: DeadOrAlive {
	var country: Country
	var ai: Bool = false
	var alive: Bool = true
	var prestige: UInt16 = 0xF00
	var crystals: Crystals = .empty
	var visible: SetXY = .empty
}

enum Country: UInt8, Hashable, CaseIterable {
	case swe, den, ned, ukr, rus, irn, pak, ind, usa, isr

	static var `default`: Self { .swe }
}

enum Team: UInt8, Hashable {
	case axis, allies, soviet
}

extension Country {

	var team: Team {
		switch self {
		case .den, .ned, .swe, .ukr: .axis
		case .isr, .pak, .usa: .allies
		case .ind, .irn, .rus: .soviet
		}
	}
}

extension Player {

	static var none: Self {
		.init(country: .default, alive: false)
	}
}
