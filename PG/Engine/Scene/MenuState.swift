struct MenuState<Action> {
	var items: [MenuItem<Action>]
	var cursor: Int = 0
	var close: (MenuState<Action>) -> MenuState<Action>? = { _ in nil }
	var action: MenuAction?
}

enum MenuAction { case close, action(Int) }

struct MenuItem<Action> {
	var icon: String
	var status: Status
	var action: Action?
	var update: (MenuState<Action>) -> MenuState<Action>?
}

extension MenuItem {

	static var space: Self {
		.init(icon: "Clear", status: .init(), update: id)
	}

	static func close(icon: String, status: String, action: Action? = nil, update: @escaping (MenuState<Action>) -> Void = ø) -> Self {
		.close(icon: icon, status: .init(text: status), action: action, update: update)
	}

	static func close(icon: String, status: Status, action: Action? = nil, update: @escaping (MenuState<Action>) -> Void = ø) -> Self {
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

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .tile(let xy): cursor = xy.x
		case .action(.a): action = .action(cursor)
		case .menu, .action(.b): action = .close
		default: break
		}
	}

	mutating func moveCursor(_ direction: Direction) {
		cursor = switch direction {
		case .down: (cursor + min(cols, items.count)) % items.count
		case .up: (cursor - min(cols, items.count) + items.count) % items.count
		case .right: (cursor + 1) % items.count
		case .left: (cursor - 1 + items.count) % items.count
		}
	}
}
