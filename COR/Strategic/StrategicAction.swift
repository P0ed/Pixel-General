public enum StrategicAction {

}

public extension StrategicState {

	mutating func reduce(_ action: StrategicAction?) -> [StrategicEvent] {
		[]
	}
}
