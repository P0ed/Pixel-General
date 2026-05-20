import AppKit

@MainActor
struct SceneMode<State: ~Copyable, Action, Event, Nodes> {
	var make: @MainActor (Scene<State, Action, Event, Nodes>) -> Nodes
	var input: @MainActor (inout State, Input) -> Action?
	var ai: @MainActor (borrowing State) -> Action? = { _ in nil }
	var reduce: @MainActor (inout State, Action?) -> [Event]
	var process: @MainActor (Event, Nodes, borrowing State) async -> Void
	var update: @MainActor (Nodes, borrowing State) -> Void
	var status: @MainActor (borrowing State) -> Status
	var keyboard: @MainActor (Nodes, NSEvent) -> Input? = { _, e in Input(keyboardEvent: e) }
	var mouse: @MainActor (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
