extension TacticalState {

	/// Per-turn plan for an AI player. Computed once at the start of the
	/// player's turn (`plan`) and then consulted by the action generators on
	/// every subsequent call until the turn rolls over.
	///
	/// The plan assigns every controllable unit a `Role` plus a target tile.
	/// Roles encode *intent* (defend a town, push the front, fall back) while
	/// the concrete move/attack targets are re-derived from live state, so the
	/// plan stays valid even as the board changes mid-turn.
	struct AI {
		/// Game `turn` this plan was built for. `.max` means "no plan yet".
		var turn: UInt32 = .max
		var role: [128 of Role] = .init(repeating: .idle)
		var target: [128 of XY] = .init(repeating: .zero)

		enum Role: UInt8 {
			case idle      // no assignment (e.g. freshly built unit)
			case retreat   // withdraw to a haven to heal / rearm
			case defend    // garrison a threatened own settlement
			case hunt      // artillery / AA / air seeking enemy units
			case attack    // ground unit pushing to capture a settlement
			case support   // supply trailing the main force
		}
	}

	static var ai: (borrowing TacticalState) -> TacticalAction? {
		var ai = TacticalState.AI()
		return { state in state.run(&ai) }
	}

	private func run(_ ai: inout AI) -> TacticalAction? {
		switch player.type {
		case .ai:
			switch player.country.team {
			case .axis, .allies: axis(ai: &ai)
			case .soviet: soviet(ai: &ai)
			}
		default: .none
		}
	}
}
