public extension TacticalSim {

	/// Per-turn plan for an AI player. Computed once at the start of the
	/// player's turn (`plan`) and then consulted by the action generators on
	/// every subsequent call until the turn rolls over.
	///
	/// The plan assigns every controllable unit a `Role` plus a target tile.
	/// Roles encode *intent* (defend a town, push the front, fall back).
	struct AI: ~Copyable {
		/// Game `turn` this plan was built for.
		public var turn: UInt32?
		public var role: [128 of Role] = .init(repeating: .idle)
		public var target: [128 of XY] = .init(repeating: .zero)

		public var roster: CArray<128, UID> = .init(tail: .none)
		public var enemies: CArray<128, UID> = .init(tail: .none)

		public var ownSettlements: CArray<32, XY> = .init(tail: .zero)
		public var enemySettlements: CArray<32, XY> = .init(tail: .zero)

		@frozen public enum Role: UInt8 {
			case idle		// no assignment (e.g. freshly built unit)
			case retreat	// withdraw to a haven to heal / rearm
			case defend		// garrison a threatened own settlement
			case hunt		// artillery / AA / air seeking enemy units
			case attack		// ground unit pushing to capture a settlement
			case support	// supply trailing the main force
		}
	}
}

public extension TacticalState {

	/// The AI hook drives the composite seat but only reads simulation state.
	static var ai: (borrowing TacticalState) -> TacticalAction? {
		var ai = TacticalSim.AI()
		return { state in state.sim.run(&ai) }
	}
}

extension TacticalSim {

	func run(_ ai: inout AI) -> TacticalAction? {
		switch player.type {
		case .ai:
			switch player.country.team {
			case .axis, .allies: axis(ai: &ai)
			case .soviet: soviet(ai: &ai)
			case .none: .none
			}
		default: .none
		}
	}
}
