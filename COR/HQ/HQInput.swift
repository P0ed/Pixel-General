public extension HQState {

	mutating func apply(_ input: Input) -> Reaction<HQAction, HQEvent> {
		var events: [HQEvent] = []
		let action: HQAction? = switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction(into: &events)
		case .action(.d): nil
		case .menu: { events.append(.menu); return nil }()
		case .tile(let xy): select(xy)
		default: nil
		}
		if !events.isEmpty { return .events(events) }
		guard let action else { return .none }
		return .action(action)
	}
}

extension HQState {

	mutating func select(_ xy: XY) -> HQAction? {
		guard map.contains(xy) else { return nil }

		cursor = xy
		return mainAction()
	}

	mutating func moveCursor(_ direction: Direction) -> HQAction? {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func mainAction() -> HQAction? {
		if selected != .none {
			if selected == units[cursor]?.0 {
				selected = .none
			} else {
				defer { selected = .none }
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

	mutating func shopAction(into events: inout [HQEvent]) -> HQAction? {
		if selected != .none {
			defer { selected = .none }
			return .sell(selected.index)
		} else if units[cursor] == nil {
			events.append(.shop)
		}
		return nil
	}
}
