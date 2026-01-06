struct Player: DeadOrAlive {
	var country: Country
	var ai: Bool = false
	var alive: Bool = true
	var prestige: UInt16 = 0x500
	var crystals: Crystals = .empty
	var visible: SetXY = .empty
}

enum Country: UInt8, Hashable {
	case dnr, lnr, irn, isr, rus, swe, ukr, usa
}

enum Team: UInt8, Hashable {
	case axis, allies, soviet
}

extension Country {

	var team: Team {
		switch self {
		case .swe, .ukr: .axis
		case .isr, .usa: .allies
		case .dnr, .lnr, .irn, .rus: .soviet
		}
	}
}

extension Player {

	static var dead: Self {
		.init(country: .dnr, alive: false)
	}
}
