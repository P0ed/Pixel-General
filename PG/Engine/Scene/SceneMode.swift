import SpriteKit

struct SceneMode<State: ~Copyable, Action, Event, Nodes> {
	var make: (SKNode, borrowing State) -> Nodes
	var input: (inout State, Input) -> Action?
	var update: (borrowing State, Nodes) -> Void
	var send: (Action) async -> Action? = { action in action }
	var reduce: (inout State, Action) -> [Event]
	var process: (borrowing State, [Event], Nodes) async -> Void
	var status: (borrowing State) -> Status
	var mouse: (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var save: (borrowing State) -> Void
	var layout: (CGSize, Nodes) -> Void = ø
}
