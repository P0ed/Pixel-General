import COR
import SpriteKit

@MainActor
struct MenuState<Action> {
	var items: [MenuItem<Action>]
	var leftButtons: [4 of MenuItem<Action>] = .init(repeating: .space)
	var rightButtons: [4 of MenuItem<Action>] = .init(repeating: .space)
	var cursor: Int = 0
	var action: MenuSlot?
}

enum MenuSlot: Equatable { case item(Int), left(Int), right(Int) }

extension MenuSlot {

	static let back = MenuSlot.left(0)

	var index: Int {
		switch self {
		case .item(let index), .left(let index), .right(let index): index
		}
	}

	var modifier: InputModifiers? {
		switch self {
		case .left: .left
		case .right: .right
		case .item: nil
		}
	}
}

@MainActor
struct MenuItem<Action> {
	var icon: UIImage
	var status: Status
	var action: Action?
	var update: (inout [MenuState<Action>]) -> Void
}

extension MenuItem {

	static var space: Self {
		.init(icon: .clear, status: .init(), update: ø)
	}

	static var back: Self {
		.pop(icon: .minus, status: "Back")
	}

	static func close(icon: UIImage, status: String, action: Action? = nil, update: @MainActor @escaping () -> Void = ø) -> Self {
		.close(icon: icon, status: .init(text: status), action: action, update: update)
	}

	static func close(icon: UIImage, status: Status, action: Action? = nil, update: @MainActor @escaping () -> Void = ø) -> Self {
		MenuItem(
			icon: icon,
			status: status,
			action: action,
			update: { stk in update(); stk = [] }
		)
	}

	static func apply(icon: UIImage, status: String, action: Action? = nil) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: ø)
	}

	static func update(
		icon: UIImage,
		status: String,
		action: Action? = nil,
		menu: @escaping (inout MenuState<Action>) -> Void
	) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk in
			menu(&stk[stk.count - 1])
		})
	}

	static func push(icon: UIImage, status: String, action: Action? = nil, menu: MenuState<Action>) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk in stk.append(menu) })
	}

	static func push(
		icon: UIImage,
		status: String,
		action: Action? = nil,
		menu: @escaping () -> MenuState<Action>?
	) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk in
			menu().map { m in stk.append(m) }
		})
	}

	static func pop(icon: UIImage, status: String, action: Action? = nil) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk in stk.removeLast() })
	}

	static func pop(
		icon: UIImage,
		status: String,
		action: Action? = nil,
		menu: @escaping (inout MenuState<Action>) -> Void
	) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk in
			stk.removeLast()
			if !stk.isEmpty { menu(&stk[stk.count - 1]) }
		})
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
			action = .left(button.index)
		case .action(let button?, let modifiers) where modifiers.contains(.right):
			action = .right(button.index)
		case .tile(let xy) where xy.x != cursor: cursor = xy.x
		case .action(.a, modifiers: _), .tile: action = .item(cursor)
		case .menu, .action(.b, modifiers: _): action = .back
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

	static func confirm(icon: UIImage, status: String, action: @MainActor @escaping () -> Void) -> MenuItem {
		.push(icon: icon, status: status, menu: MenuState(
			items: [
				.pop(icon: .minus, status: "Cancel"),
				.space,
				.space,
				.close(icon: .plus, status: "Confirm", update: action),
			],
			leftButtons: [.back, .space, .space, .space]
		))
	}

	static func load(save: @escaping () -> Void) -> MenuItem {
		.push(icon: .load, status: "Load \(UserDefaults.standard.slot + 1)", menu: MenuState(
			items: (0...3).map { slot in
				.confirm(icon: .load, status: "Slot \(slot + 1)") {
					save()
					core = .load(slot: slot)
					view.present(.auto)
				}
			},
			leftButtons: [.back, .space, .space, .space]
		))
	}
}

extension UInt8 {
	mutating func toggle4() { self = (self + 1) % 4 }
	mutating func toggle6() { self = (self + 1) % 6 }
}
