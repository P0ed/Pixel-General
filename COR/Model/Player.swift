public struct Player {
	public var country: Country
	public var type: PlayerType
	public var prestige: UInt16
	public var visible: SetXY
	public var alive: Bool

	public init(
		country: Country = .default,
		type: PlayerType = .human,
		prestige: UInt16 = 0xF00,
		visible: SetXY = .empty,
		alive: Bool = true
	) {
		self.country = country
		self.type = type
		self.prestige = prestige
		self.visible = visible
		self.alive = alive
	}
}

public enum PlayerType: UInt8, Sendable {
	case human, remote, ai
}

public enum Country: UInt8, Hashable, CaseIterable, Sendable {
	case swe, den, ned, ukr, rus, irn, pak, ind, usa, isr
}

public enum Team: UInt8, Hashable, Sendable {
	case axis, allies, soviet
}

public extension Country {

	static var `default`: Self { .swe }

	var team: Team {
		switch self {
		case .den, .ned, .swe, .ukr: .axis
		case .isr, .pak, .usa: .allies
		case .ind, .irn, .rus: .soviet
		}
	}
}

extension Player {
	static var none: Self { .init(alive: false) }
}
