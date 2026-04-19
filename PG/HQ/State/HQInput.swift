
extension HQState {

	mutating func apply(_ input: Input) -> HQAction? {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction()
		case .action(.d): nil
		case .menu: { events.add(.menu); return nil }()
		case .tile(let xy): select(xy)
		default: nil
		}
	}

	mutating func select(_ xy: XY) -> HQAction? {
		guard HQNodes.map.contains(xy) else { return nil }

		cursor = xy
		return mainAction()
	}

	mutating func moveCursor(_ direction: Direction) -> HQAction? {
		let xy = cursor.neighbor(direction)
		if HQNodes.map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func mainAction() -> HQAction? {
		if let selected {
			if selected == units[cursor]?.0 {
				self.selected = .none
			} else {
				self.selected = .none
				return .swap(selected.index, cursor.x + cursor.y * 4)
			}
		} else if let (i, _) = units[cursor] {
			selected = i
		}
		return nil
	}

	mutating func secondaryAction() -> HQAction? {
		selected = .none
		return nil
	}

	mutating func shopAction() -> HQAction? {
		if let selected {
			self.selected = .none
			return .sell(selected.index)
		} else if units[cursor] == nil {
			events.add(.shop)
		}
		return nil
	}
}
