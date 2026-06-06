public struct Reaction<Action, Event> {
	public var action: Action?
	public var events: [Event]

	public init(action: Action? = nil, events: [Event] = []) {
		self.action = action
		self.events = events
	}
}
