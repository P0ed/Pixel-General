public extension StrategicState {

	mutating func apply(_ input: Input) -> Reaction<StrategicAction, StrategicEvent> {
		switch input {
		case .menu: .events([.menu])
		default: .none
		}
	}
}
