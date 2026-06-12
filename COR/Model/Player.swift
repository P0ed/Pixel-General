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

@frozen public enum PlayerType: UInt8, Sendable {
	case human, remote, ai
}

@frozen public enum Country: UInt8, Hashable, CaseIterable, Sendable {
	case swe, den, ned, ukr, rus, irn, pak, ind, usa, isr
	// European nations for the campaign map (see docs/Map.md). Armies resolve by
	// `team`, so these inherit a full roster without bespoke unit content.
	case nor, fin, ger, est, lva, ltu, pol, bel, cze, svk, aut, rom, hun, mol
	// Sentinel for unowned / water tiles on the strategic map. Never fights.
	case sea
}

@frozen public enum Team: UInt8, Hashable, Sendable {
	case axis, allies, soviet
}

public extension Country {

	static var `default`: Self { .swe }

	var team: Team {
		switch self {
		case .den, .ned, .swe, .ukr, .ger, .pol, .cze, .aut: .axis
		case .isr, .pak, .usa, .fin, .ltu, .svk, .hun: .allies
		case .ind, .irn, .rus, .nor, .est, .lva, .bel, .rom, .mol: .soviet
		case .sea: .axis // never used: sea tiles are excluded from combat
		}
	}

	// Selectable nations, excluding the `.sea` strategic-map sentinel.
	static var playable: [Country] { allCases.filter { $0 != .sea } }
}

extension Player {
	static var none: Self { .init(alive: false) }
}
