public enum StrategicAction {

}

public extension StrategicState {

	mutating func reduce(_ action: StrategicAction?) -> [StrategicEvent] {
		defer { events.erase() }
		return events.map { _, e in e }
	}
}
