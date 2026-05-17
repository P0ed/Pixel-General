import AppKit

@MainActor
struct SceneMode<State: ~Copyable, UI, Action, Event, Nodes> {
	var make: @MainActor (Scene<State, UI, Action, Event, Nodes>) -> Nodes
	/// Input stage: simulation `State` is read-only (borrowed). Only `UI`
	/// (cursor/camera/selection/zoom) may change here; the simulation can
	/// change solely by emitting an `Action` for the reduce stage.
	var input: @MainActor (borrowing State, inout UI, Input) -> Action?
	var update: @MainActor (Nodes, borrowing State, borrowing UI) -> Void
	/// Reduce stage: the only place `State` mutates, driven by an `Action`.
	/// `UI` is also `inout` so post-action selection can be re-synced.
	var reduce: @MainActor (inout State, inout UI, Action?) -> [Event]
	var process: @MainActor (Event, Nodes, borrowing State, borrowing UI) async -> Void
	var status: @MainActor (borrowing State, borrowing UI) -> Status
	var mouse: @MainActor (Nodes, NSEvent) -> Input? = { _, _ in .none }
	var auto: @MainActor (borrowing State) -> Action? = { _ in nil }
	/// Inputs safe to apply while a `Task` is in flight: view-only, must
	/// return no `Action` and emit no events (e.g. camera pan/zoom).
	var live: @MainActor (Input) -> Bool = { _ in false }
	/// Cheap view-only flush for `live` inputs, since the full `update` is
	/// suppressed during processing.
	var liveUpdate: @MainActor (Nodes, borrowing State, borrowing UI) -> Void = { _, _, _ in }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
