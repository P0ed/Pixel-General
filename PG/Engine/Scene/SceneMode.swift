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
	var auto: @MainActor (borrowing State) -> Action? = { _ in nil }
	/// Inputs safe to apply while a `Task` is in flight: view-only, must
	/// return no `Action` and emit no events (e.g. camera pan/zoom).
	var live: @MainActor (Input) -> Bool = { _ in false }
	/// Cheap view-only flush for `live` inputs, since the full `update` is
	/// suppressed during processing.
	var liveUpdate: @MainActor (Nodes, borrowing State) -> Void = { _, _ in }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
