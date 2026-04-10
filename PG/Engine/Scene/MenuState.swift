struct MenuState<State: ~Copyable> {
	var items: [MenuItem<State>]
	var cursor: Int = 0
	var close: (inout State) -> MenuState<State>? = { _ in nil }
	var action: MenuAction?
}

enum MenuAction { case close, apply(Int) }

struct MenuItem<State: ~Copyable> {
	var icon: String
	var status: String
	var action: String = ""
	var update: (inout State, MenuState<State>) -> MenuState<State>?
}

extension MenuItem where State: ~Copyable {

	static func close(icon: String, status: String, action: String = "", update: @escaping (inout State) -> Void) -> Self {
		MenuItem(
			icon: icon,
			status: status,
			action: action,
			update: { state, menu in update(&state); return .none }
		)
	}
}

extension MenuState where State: ~Copyable {

	var rows: Int { 4 }
	var cols: Int { 4 }

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .tile(let xy): cursor = xy.x
		case .action(.a): action = .apply(cursor)
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
