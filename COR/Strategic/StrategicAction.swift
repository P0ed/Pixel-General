@frozen public enum StrategicAction {
	/// Launch an offensive against the enemy province at `XY`.
	case attack(XY)
	case endTurn
}

public extension StrategicState {

	mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		var events: [StrategicEvent] = []
		switch action {
		case .attack(let xy): events.append(.attack(xy))
		case .endTurn: turn += 1
		}
		return events
	}
}
