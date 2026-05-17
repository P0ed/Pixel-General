extension StrategicUI {

	mutating func apply(_ input: Input, _ s: borrowing StrategicState) -> StrategicAction? {
		switch input {
		case .menu: .menu
		default: nil
		}
	}
}
