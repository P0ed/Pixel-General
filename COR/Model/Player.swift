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

/// In a networked battle `PlayerType` is peer-relative: every peer marks the
/// seats it drives `.human`, every seat driven elsewhere `.remote`, and only
/// the host keeps `.ai` seats. `.remote` uniformly means "someone else drives
/// this — wait for the wire". Reduce never branches on it for game-relevant
/// state (only for UI selection), so peers stay deterministic while
/// disagreeing about seat types.
@frozen public enum PlayerType: UInt8, Sendable {
	case human, remote, ai
}

@frozen public enum Country: UInt8, Hashable, CaseIterable, Sendable {
	case none
	case swe, den, ned, ukr, rus, irn, pak, ind, usa, isr
	case nor, fin, ger, est, lva, ltu, pol, bel, cze, svk, aut, rom, hun, mol
}

@frozen public enum Team: UInt8, Hashable, Sendable {
	case none, axis, allies, soviet
}

public extension Country {

	static var `default`: Self { .swe }

	var team: Team {
		switch self {
		case .den, .ned, .swe, .ukr, .ger, .pol, .cze, .aut, .nor: .axis
		case .isr, .pak, .usa, .fin, .ltu, .svk, .hun: .allies
		case .ind, .irn, .rus, .est, .lva, .bel, .rom, .mol: .soviet
		case .none: .none
		}
	}

	// Selectable nations
	static var playable: [Country] { allCases.filter { $0 != .none } }
}

extension Player {
	static var none: Self { .init(alive: false) }
}
