import AppKit
import COR

@MainActor
struct SceneMode<State: ~Copyable, Action, Event, Nodes> {
	var make: @MainActor (Scene<State, Action, Event, Nodes>) -> Nodes
	var input: @MainActor (inout State, Input) -> Reaction<Action, Event>
	var ai: @MainActor (borrowing State) -> Action? = { _ in nil }
	/// Multiplayer hook: inspects a locally produced action before Reduce.
	/// Returning true suppresses the local apply (the action was handed to
	/// the network authority instead).
	var relay: @MainActor (borrowing State, Action) -> Bool = { _, _ in false }
	var reduce: @MainActor (inout State, Action) -> [Event] = { _, _ in [] }
	var process: @MainActor (Event, Nodes, borrowing State) async -> Void
	var update: @MainActor (Nodes, borrowing State) -> Void
	var status: @MainActor (borrowing State) -> Status
	var keyboard: @MainActor (Nodes, NSEvent) -> Input? = { _, e in Input(keyboardEvent: e) }
	var mouse: @MainActor (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
