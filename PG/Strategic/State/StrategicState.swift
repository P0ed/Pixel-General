struct StrategicState: ~Copyable {
	var events: CArray<16, StrategicEvent> = .init(tail: .menu)
}

/// Session/UI state for the strategic scene (none yet). Owned by `Scene`.
struct StrategicUI {}

extension StrategicState {

	var status: Status {
		.init()
	}
}
