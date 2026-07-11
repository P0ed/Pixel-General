public extension HQState {

	mutating func apply(_ input: Input) -> HQReaction {
		switch input {
		case .direction(let direction?, modifiers: let modifiers) where modifiers.isEmpty:
			moveCursor(direction)
		case .action(.a, modifiers: let modifiers) where modifiers.isEmpty: mainAction()
		case .action(.b, modifiers: let modifiers) where modifiers.isEmpty: secondaryAction()
		case .action(.c, modifiers: let modifiers) where modifiers.isEmpty: upgradeAction()
		case .action(.d, modifiers: let modifiers) where modifiers.isEmpty: sellAction()
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

	/// `.c` opens the upgrade menu for the *selected* unit; with nothing
	/// selected it falls back to the purchase shop on an empty slot.
	mutating func upgradeAction() -> HQReaction {
		if ui.selected != .none {
			return .events([.upgrade(ui.selected)])
		} else if sim.units[ui.cursor] == nil {
			return .events([.shop])
		} else {
			return .none
		}
	}

	/// `.d` sells the selected unit.
	mutating func sellAction() -> HQReaction {
		guard ui.selected != .none else { return .none }
		defer { ui.selected = .none }
		return .action(.sell(ui.selected.index))
	}
}
