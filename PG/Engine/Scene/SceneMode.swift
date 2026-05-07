import AppKit

@MainActor
struct SceneMode<State: ~Copyable, Action, Event, Nodes> {
	var make: @MainActor (Scene<State, Action, Event, Nodes>) -> Nodes
	var input: @MainActor (inout State, Input) -> Action?
	var update: @MainActor (Nodes, borrowing State) -> Void
	var reduce: @MainActor (inout State, Action?) -> [Event]
	var process: @MainActor (Event, Nodes, borrowing State) async -> Void
	var status: @MainActor (borrowing State) -> Status
	var mouse: @MainActor (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
