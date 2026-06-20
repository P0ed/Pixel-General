public struct Player {
	public var country: Country
	public var type: PlayerType
	public var prestige: UInt16
	public var baseLevel: UInt8
	public var tier: UInt8
	public var alive: Bool

	public init(
		country: Country = .default,
		type: PlayerType = .human,
		prestige: UInt16 = 0xF00,
		baseLevel: UInt8 = 0,
		tier: UInt8 = 0,
		alive: Bool = true
	) {
		self.country = country
		self.type = type
		self.prestige = prestige
		self.baseLevel = baseLevel
		self.tier = tier
		self.alive = alive
	}
}

@frozen public enum PlayerType: UInt8, Sendable {
	case human, remote, ai
}

@frozen public enum Country: UInt8, Hashable, CaseIterable, Sendable {
	case none
	case swe, den, ned, nor, fin, ger, est, lva, ltu, pol, cze, aut, ukr
	case rus, irn, bel, svk, rom, hun, mol, ind
	case usa, isr, pak
}

@frozen public enum Team: UInt8, Hashable, Sendable {
	case none, axis, allies, soviet
}

public extension Country {

	static var `default`: Self { .swe }

	var team: Team {
		switch self {
		case .den, .ned, .swe, .ukr, .ger, .pol, .cze, .aut, .nor, .fin, .est, .lva, .ltu: .axis
		case .isr, .pak, .usa: .allies
		case .ind, .irn, .rus, .bel, .rom, .mol, .svk, .hun: .soviet
		case .none: .none
		}
	}

	static var playable: [Country] { allCases.filter { $0 != .none } }
}

extension Player {
	static var none: Self { .init(alive: false) }
}

public extension UInt16 {
	static var poor: Self { 0x0A00 }
	static var rich: Self { 0x1F00 }
}
