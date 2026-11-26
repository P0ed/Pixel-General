import UIKit
import COR

@MainActor
struct SceneMode<State: ~Copyable, Action, Event, PresentationIntent, Nodes> {
	var make: @MainActor (Scene<State, Action, Event, PresentationIntent, Nodes>) -> Nodes
	var initialMenu: @MainActor (Nodes, borrowing State) -> MenuState<Action>? = { _, _ in nil }
	var input: @MainActor (inout State, Input) -> InputReaction<Action, PresentationIntent>
	var next: @MainActor (borrowing State) -> Action? = { _ in nil }
	var reduce: @MainActor (inout State, Action) -> [Event] = { _, _ in [] }
	var process: @MainActor (Event, Nodes, borrowing State) async -> Void
	var present: @MainActor (PresentationIntent, Nodes, borrowing State) async -> Void
	var update: @MainActor (Nodes, borrowing State) -> Void
	var status: @MainActor (borrowing State) -> Status
	var cameraPosition: @MainActor (borrowing State) -> CGPoint? = { _ in nil }
	var keyboard: @MainActor (Nodes, UIKey) -> Input? = { _, k in Input(key: k) }
	var mouse: @MainActor (Nodes, CGPoint) -> Input? = { _, _ in .none }
	var save: @MainActor (borrowing State) -> Void = { _ in }
	var layout: @MainActor (CGSize, Nodes) -> Void = { _, _ in }
}
