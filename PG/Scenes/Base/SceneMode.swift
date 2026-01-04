import SpriteKit

struct SceneMode<State: ~Copyable, Event, Nodes> {
	var make: (SKNode, borrowing State) -> Nodes
	var inputable: (borrowing State) -> Bool
	var input: (inout State, Input) -> Void
	var update: (borrowing State, Nodes) -> Void
	var reducible: (borrowing State) -> Bool
	var reduce: (inout State) -> [Event]
	var respawn: (Scene<State, Event, Nodes>) -> Void
	var process: (Scene<State, Event, Nodes>, [Event]) async -> Void
	var status: (borrowing State) -> String
	var mouse: (Nodes, NSEvent) -> Input?
	var save: (borrowing State) -> Void
	var layout: (CGSize, Nodes) -> Void = ø
}
