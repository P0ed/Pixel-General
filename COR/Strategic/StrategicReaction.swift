public typealias StrategicReaction = Reaction<StrategicAction, StrategicEvent>

@frozen public enum StrategicAction {
	/// Launch an offensive against the enemy province at `XY`.
	case attack(XY)
	case endTurn
}

@frozen public enum StrategicEvent {
	case attack(XY)
	case menu
}

public extension StrategicSim {

	mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		var events: [StrategicEvent] = []
		switch action {
		case .attack(let xy): events.append(.attack(xy))
		case .endTurn: turn += 1
		}
		return events
	}
}

extension StrategicState {

	/// Mirrors `TacticalState.reduce`: the mode always reduces through `State`,
	/// which delegates the deterministic mutation to `sim`. Strategic has no UI
	/// to reconcile afterwards.
	public mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		sim.reduce(action)
	}
}
