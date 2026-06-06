public extension StrategicState {

	mutating func apply(_ input: Input) -> Reaction<StrategicAction, StrategicEvent> {
		var events: [StrategicEvent] = []
		switch input {
		case .menu: events.append(.menu)
		default: break
		}
		return .init(events: events)
	}
}
