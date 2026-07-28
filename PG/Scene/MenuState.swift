import COR
import SpriteKit

@MainActor
struct MenuState<Action> {
	var items: [MenuItem<Action>]
	var leftButtons: [4 of MenuItem<Action>] = [.back, .space, .space, .space]
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
	/// Runs against the whole stack, told which slot fired so a control can
	/// write back to itself without knowing where it sits.
	var update: (inout [MenuState<Action>], MenuSlot) -> Void
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
			update: { stk, _ in update(); stk = [] }
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
		.init(icon: icon, status: .init(text: status), action: action, update: { stk, _ in
			menu(&stk[stk.count - 1])
		})
	}

	/// A control that redraws itself in place: `change` mutates the value the
	/// item stands for, then icon and status are recomputed from it. The item
	/// addresses itself through the slot it fired from, so reordering a menu
	/// can never leave it pointing at a neighbour.
	static func toggle(
		icon: @autoclosure @MainActor @escaping () -> UIImage,
		status: @autoclosure @MainActor @escaping () -> String,
		action: Action? = nil,
		change: @MainActor @escaping () -> Void
	) -> Self {
		.init(icon: icon(), status: .init(text: status()), action: action, update: { stk, slot in
			change()
			stk[stk.count - 1][slot].icon = icon()
			stk[stk.count - 1][slot].status.text = status()
		})
	}

	static func push(icon: UIImage, status: String, action: Action? = nil, menu: MenuState<Action>) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk, _ in stk.append(menu) })
	}

	static func push(
		icon: UIImage,
		status: String,
		action: Action? = nil,
		menu: @escaping () -> MenuState<Action>?
	) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk, _ in
			menu().map { m in stk.append(m) }
		})
	}

	static func pop(icon: UIImage, status: String, action: Action? = nil) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk, _ in stk.removeLast() })
	}

	static func pop(
		icon: UIImage,
		status: String,
		action: Action? = nil,
		menu: @escaping (inout MenuState<Action>) -> Void
	) -> Self {
		.init(icon: icon, status: .init(text: status), action: action, update: { stk, _ in
			stk.removeLast()
			if !stk.isEmpty { menu(&stk[stk.count - 1]) }
		})
	}
}

extension MenuState {

	var cols: Int { 4 }

	subscript(slot: MenuSlot) -> MenuItem<Action> {
		get {
			switch slot {
			case .item(let index): items[index]
			case .left(let index): leftButtons[index]
			case .right(let index): rightButtons[index]
			}
		}
		set {
			switch slot {
			case .item(let index): items[index] = newValue
			case .left(let index): leftButtons[index] = newValue
			case .right(let index): rightButtons[index] = newValue
			}
		}
	}

	mutating func apply(_ input: Input) {
		if let slot = input.menuSlot {
			action = slot
			return
		}
		switch input {
		case .direction(let direction?, modifiers: _): moveCursor(direction)
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
			]
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
			}
		))
	}
}

extension UInt8 {
	mutating func toggle4() { self = (self + 1) % 4 }
	mutating func toggle6() { self = (self + 1) % 6 }
}
