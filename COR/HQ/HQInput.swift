public extension HQState {

	mutating func apply(_ input: Input) -> HQReaction {
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

	mutating func select(_ xy: XY) -> HQReaction {
		guard sim.map.contains(xy) else { return .none }

		ui.cursor = xy
		return mainAction()
	}

	mutating func moveCursor(_ direction: Direction) -> HQReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.map.contains(xy) { ui.cursor = xy }
		return .none
	}

	mutating func mainAction() -> HQReaction {
		if ui.selected != .none {
			if ui.selected == sim.units[ui.cursor]?.0 {
				ui.selected = .none
			} else {
				defer { ui.selected = .none }
				return .action(.swap(ui.selected.index, ui.cursor.x + ui.cursor.y * 4))
			}
		} else if let (i, _) = sim.units[ui.cursor] {
			ui.selected = i
		}
		return .none
	}

	mutating func secondaryAction() -> HQReaction {
		ui.selected = .none
		return .none
	}

	mutating func shopAction() -> HQReaction {
		if ui.selected != .none {
			defer { ui.selected = .none }
			return .action(.sell(ui.selected.index))
		} else if sim.units[ui.cursor] == nil {
			return .events([.shop])
		} else {
			return .none
		}
	}
}
