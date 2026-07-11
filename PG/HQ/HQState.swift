import COR

struct HQUI {
	var cursor: XY
	var selected: UID

	init(cursor: XY = .zero, selected: UID = .none) {
		self.cursor = cursor
		self.selected = selected
	}
}

struct HQState: ~Copyable {
	var sim: HQSim
	var ui: HQUI

	init(sim: consuming HQSim, ui: HQUI = HQUI()) {
		self.sim = sim
		self.ui = ui
	}

	mutating func reduce(_ action: HQAction) -> [HQEvent] {
		sim.reduce(action)
	}
}

enum HQPresentationIntent {
	case shop
	case upgrade(UID)
	case menu
}

typealias HQInputReaction = InputReaction<HQAction, HQPresentationIntent>

extension HQState {

	mutating func apply(_ input: Input) -> HQInputReaction {
		switch input {
		case .direction(let direction?, modifiers: let modifiers) where modifiers.isEmpty:
			moveCursor(direction)
		case .action(.a, modifiers: let modifiers) where modifiers.isEmpty: mainAction()
		case .action(.b, modifiers: let modifiers) where modifiers.isEmpty: secondaryAction()
		case .action(.c, modifiers: let modifiers) where modifiers.isEmpty: upgradeAction()
		case .action(.d, modifiers: let modifiers) where modifiers.isEmpty: sellAction()
		case .menu: .presentation(.menu)
		case .tile(let xy): select(xy)
		default: .none
		}
	}

	private mutating func select(_ xy: XY) -> HQInputReaction {
		guard sim.map.contains(xy) else { return .none }
		ui.cursor = xy
		return mainAction()
	}

	private mutating func moveCursor(_ direction: Direction) -> HQInputReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.map.contains(xy) { ui.cursor = xy }
		return .none
	}

	private mutating func mainAction() -> HQInputReaction {
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

	private mutating func secondaryAction() -> HQInputReaction {
		ui.selected = .none
		return .none
	}

	private mutating func upgradeAction() -> HQInputReaction {
		if ui.selected != .none {
			.presentation(.upgrade(ui.selected))
		} else if sim.units[ui.cursor] == nil {
			.presentation(.shop)
		} else {
			.none
		}
	}

	private mutating func sellAction() -> HQInputReaction {
		guard ui.selected != .none else { return .none }
		defer { ui.selected = .none }
		return .action(.sell(ui.selected.index))
	}
}
