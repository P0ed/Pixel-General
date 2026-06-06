public struct StrategicState: ~Copyable {
	public var events: CArray<16, StrategicEvent>

	public init(
		events: consuming CArray<16, StrategicEvent> = .init(tail: .menu)
	) {
		self.events = events
	}
}
