extension TacticalState {
	
	struct AI {
		var turn: UInt32
		var defenders: [32 of UID] = .init(repeating: -1)
		var attackers: [32 of UID] = .init(repeating: -1)
	}

	func runAIIfNeeded(ai: inout AI) -> TacticalAction? {
		guard player.type == .ai else { return .none }

		return switch player.country.team {
		case .allies: axis(ai: &ai)
		case .soviet: soviet(ai: &ai)
		case .axis: axis(ai: &ai)
		}
	}
}
