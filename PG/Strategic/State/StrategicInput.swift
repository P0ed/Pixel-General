extension StrategicState {

	mutating func apply(_ input: Input) -> StrategicAction? {
		switch input {
		case .menu: events.add(.menu)
		default: break
		}
		return nil
	}
}
