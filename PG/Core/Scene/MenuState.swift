struct MenuState<State: ~Copyable> {
	var items: [MenuItem<State>]
	var cursor: Int = 0
	var action: MenuAction?
}

enum MenuAction {
	case close, apply(Int)
}

struct MenuItem<State: ~Copyable> {
	var icon: String
	var status: String
	var action: String = ""
	var update: (inout State) -> Void
}

extension MenuState where State: ~Copyable {

	var rows: Int { 3 }
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
