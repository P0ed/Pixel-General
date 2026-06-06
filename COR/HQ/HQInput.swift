public extension HQState {

	mutating func apply(_ input: Input) -> Reaction<HQAction, HQEvent> {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction()
		case .action(.d): .none
		case .menu: .events([.menu])
		case .tile(let xy): select(xy)
		default: .none
		}
	}
}

extension HQState {

	mutating func select(_ xy: XY) -> Reaction<HQAction, HQEvent> {
		guard map.contains(xy) else { return .none }

		cursor = xy
		return mainAction()
	}

	mutating func moveCursor(_ direction: Direction) -> Reaction<HQAction, HQEvent> {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
		return .none
	}

	mutating func mainAction() -> Reaction<HQAction, HQEvent> {
		if selected != .none {
			if selected == units[cursor]?.0 {
				selected = .none
			} else {
				defer { selected = .none }
				return .action(.swap(selected.index, cursor.x + cursor.y * 4))
			}
		} else if let (i, _) = units[cursor] {
			selected = i
		}
		return .none
	}

	mutating func secondaryAction() -> Reaction<HQAction, HQEvent> {
		selected = .none
		return .none
	}

	mutating func shopAction() -> Reaction<HQAction, HQEvent> {
		if selected != .none {
			defer { selected = .none }
			return .action(.sell(selected.index))
		} else if units[cursor] == nil {
			return .events([.shop])
		} else {
			return .none
		}
	}
}
