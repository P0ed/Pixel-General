import COR
import SpriteKit

@MainActor
struct MenuState<Action> {
	var items: [MenuItem<Action>]
	/// Side panel buttons, `A`...`D` top to bottom, fired by `L+A`...`L+D`.
	var leftButtons: [4 of MenuItem<Action>] = .init(repeating: .space)
	/// Side panel buttons, `A`...`D` top to bottom, fired by `R+A`...`R+D`.
	var rightButtons: [4 of MenuItem<Action>] = .init(repeating: .space)
	var cursor: Int = 0
	var close: (MenuState<Action>) -> MenuState<Action>? = { _ in nil }
	var action: MenuAction?
}

enum MenuAction { case close, action(MenuSlot) }

/// Which of the menu's three panels fired: the grid, or a side button index.
enum MenuSlot: Equatable { case item(Int), left(Int), right(Int) }

@MainActor
struct MenuItem<Action> {
	var icon: UIImage
	var status: Status
	var action: Action?
	var update: (MenuState<Action>) -> MenuState<Action>?
}

extension MenuItem {

	static var space: Self {
		.init(icon: .clear, status: .init(), update: id)
	}

	static func close(icon: UIImage, status: String, action: Action? = nil, update: @MainActor @escaping (MenuState<Action>) -> Void = ø) -> Self {
		.close(icon: icon, status: .init(text: status), action: action, update: update)
	}

	static func close(icon: UIImage, status: Status, action: Action? = nil, update: @MainActor @escaping (MenuState<Action>) -> Void = ø) -> Self {
		MenuItem(
			icon: icon,
			status: status,
			action: action,
			update: { menu in update(menu); return .none }
		)
	}
}

extension MenuState {

	var rows: Int { 4 }
	var cols: Int { 4 }
	var page: Int { rows * cols }

	var pages: Int { (items.count - 1) / page + 1 }

	subscript(slot: MenuSlot) -> MenuItem<Action> {
		switch slot {
		case .item(let index): items[index]
		case .left(let index): leftButtons[index]
		case .right(let index): rightButtons[index]
		}
	}

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction?, modifiers: _): moveCursor(direction)
		case .action(let button?, let modifiers) where modifiers.contains(.left):
			action = .action(.left(button.index))
		case .action(let button?, let modifiers) where modifiers.contains(.right):
			action = .action(.right(button.index))
		case .tile(let xy) where xy.x != cursor: cursor = xy.x
		case .action(.a, modifiers: _), .tile: action = .action(.item(cursor))
		case .menu, .action(.b, modifiers: _): action = .close
		default: break
		}
	}

	mutating func moveCursor(_ direction: Direction) {
		cursor = switch direction {
		case .down: (cursor + min(cols, items.count)) % items.count
		case .up: (cursor - min(cols, items.count) + items.count) % items.count
		case .left: (cursor / 4 * 4 + (4 + cursor - 1) % 4) % items.count
		case .right: (cursor / 4 * 4 + (cursor + 1) % 4) % items.count
		}
	}
}

import Foundation

extension MenuItem {

	/// An item that pushes a single-item confirmation submenu; `action` runs
	/// only on the second tap, closing back cancels.
	static func confirm(icon: UIImage, status: String, action: @MainActor @escaping () -> Void) -> MenuItem {
		MenuItem(icon: icon, status: .init(text: status), update: { menu in
			MenuState(
				items: [
					.init(icon: .empty, status: .init(text: "Cancel")) { _ in menu },
					.space,
					.space,
					.close(icon: .new, status: "Confirm") { _ in action() },
				],
				close: { _ in menu }
			)
		})
	}

	static func load(save: @escaping () -> Void) -> MenuItem {
		MenuItem(icon: .load, status: .init(text: "Load \(UserDefaults.standard.slot + 1)"), update: { state in
			MenuState(
				items: (0...3).map { slot in
						.confirm(icon: .load, status: "Slot \(slot + 1)") {
							save()
							core = .load(slot: slot)
							view.present(.auto)
						}
				},
				close: { _ in
					state
				}
			)
		})
	}
}

extension UInt8 {
	mutating func toggle4() { self = (self + 1) % 4 }
	mutating func toggle6() { self = (self + 1) % 6 }
}
