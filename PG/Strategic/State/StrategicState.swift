struct StrategicState: ~Copyable {
	var events: CArray<16, StrategicEvent> = .init(tail: .menu)
}

extension StrategicState {

	var status: Status {
		.init()
	}
}
