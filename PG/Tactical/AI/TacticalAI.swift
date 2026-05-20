extension TacticalState {
	
	struct AI {
		var turn: UInt32
		var defenders: [32 of UID] = .init(repeating: -1)
		var attackers: [32 of UID] = .init(repeating: -1)
	}
	
	func runAIIfNeeded(ai: inout AI) -> TacticalAction? {
		guard player.type == .ai else { return .none }

		if ai.turn != turn { ai = AI(turn: turn) }
		return axisAI(ai: &ai)

		return switch player.country.team {
		case .allies: alliesAI(ai: &ai)
		case .soviet: sovietAI()
		case .axis: axisAI(ai: &ai)
		}
	}
}
