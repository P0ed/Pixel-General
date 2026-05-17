extension HQUI {

	mutating func apply(_ input: Input, _ s: borrowing HQState) -> HQAction? {
		switch input {
		case .direction(let direction?): moveCursor(direction, s)
		case .action(.a): mainAction(s)
		case .action(.b): secondaryAction()
		case .action(.c): shopAction(s)
		case .action(.d): nil
		case .menu: .menu
		case .tile(let xy): select(xy, s)
		default: nil
		}
	}

	mutating func select(_ xy: XY, _ s: borrowing HQState) -> HQAction? {
		guard s.map.contains(xy) else { return nil }

		cursor = xy
		return mainAction(s)
	}

	mutating func moveCursor(_ direction: Direction, _ s: borrowing HQState) -> HQAction? {
		let xy = cursor.neighbor(direction)
		if s.map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func mainAction(_ s: borrowing HQState) -> HQAction? {
		if let selected {
			if selected == s.units[cursor]?.0 {
				self.selected = .none
			} else {
				self.selected = .none
				return .swap(selected.index, cursor.x + cursor.y * 4)
			}
		} else if let (i, _) = s.units[cursor] {
			selected = i
		}
		return nil
	}

	mutating func secondaryAction() -> HQAction? {
		selected = .none
		return nil
	}

	mutating func shopAction(_ s: borrowing HQState) -> HQAction? {
		if let selected {
			self.selected = .none
			return .sell(selected.index)
		} else if s.units[cursor] == nil {
			return .shop
		}
		return nil
	}
}
