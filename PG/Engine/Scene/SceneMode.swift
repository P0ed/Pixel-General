import SpriteKit

struct SceneMode<State: ~Copyable, Action, Event, Nodes> {
	var make: (Scene<State, Action, Event, Nodes>) -> Nodes
	var input: (inout State, Input) -> Action?
	var update: (Nodes, borrowing State) -> Void
	var reduce: (inout State, Action?) -> [Event]
	var process: (Event, Nodes, borrowing State) async -> Void
	var status: (borrowing State) -> Status
	var mouse: (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var save: (borrowing State) -> Void = { _ in }
	var layout: (CGSize, Nodes) -> Void = { _, _ in }
}
