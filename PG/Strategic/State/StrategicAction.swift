enum StrategicAction {
	case menu
}

extension StrategicState {

	mutating func reduce(_ action: StrategicAction?) -> [StrategicEvent] {
		switch action {
		case .menu: events.add(.menu)
		case .none: break
		}
		defer { events.erase() }
		return events.map { _, e in e }
	}
}
