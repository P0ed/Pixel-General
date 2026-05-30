extension TacticalState {
	
	struct AI {
		var turn: UInt32
		var defenders: [32 of UID] = .init(repeating: .none)
		var attackers: [32 of UID] = .init(repeating: .none)
	}

	static var ai: (borrowing TacticalState) -> TacticalAction? {
		var ai = TacticalState.AI(turn: 0)
		return { state in state.run(&ai) }
	}

	private func run(_ ai: inout AI) -> TacticalAction? {
		switch player.type {
		case .ai:
			switch player.country.team {
			case .allies: axis(ai: &ai)
			case .axis: axis(ai: &ai)
			case .soviet: soviet(ai: &ai)
			}
		default: .none
		}
	}
}
