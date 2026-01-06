struct MenuState<State: ~Copyable> {
	var layout: MenuLayout
	var items: [MenuItem<State>]
	var cursor: Int = 0
	var action: MenuAction?
}

enum MenuLayout {
	case compact, inspector
}

enum MenuAction {
	case close, apply(Int)
}

struct MenuItem<State: ~Copyable> {
	var icon: String
	var text: String
	var description: String?
	var action: (inout State) -> Void
}

extension MenuState where State: ~Copyable {

	var rows: Int { layout == .compact ? 1 : 3 }
	var cols: Int { layout == .inspector ? 3 : 5 }

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction): moveCursor(direction)
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
