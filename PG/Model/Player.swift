struct Player: DeadOrAlive {
	var country: Country = .default
	var type: PlayerType = .human
	var alive: Bool = true
	var prestige: UInt16 = 0xF00
	var visible: SetXY = .empty
}

enum PlayerType: UInt8 {
	case human, remote, ai
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
