public extension StrategicState {

	mutating func apply(_ input: Input) -> StrategicReaction {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .tile(let xy): select(xy)
		case .action(.a): primary(at: ui.cursor)
		case .action(.b): build(at: ui.cursor)
		case .action(.c): army(at: ui.cursor)
		case .menu: .events([.menu])
		case .mode: toggleMapMode()
		case .scale(let value): { ui.scale = value; return .none }()
		case .pan(let dxy): handlePan(dxy)
		default: .none
		}
	}

	private mutating func moveCursor(_ direction: Direction) -> StrategicReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.owner.contains(xy) { ui.cursor = xy }
		return .none
	}

	private mutating func select(_ xy: XY) -> StrategicReaction {
		guard sim.owner.contains(xy) else { return .none }
		ui.cursor = xy
		return primary(at: xy)
	}

	/// A: order a selected army to march, toggle army selection, or attack.
	private mutating func primary(at xy: XY) -> StrategicReaction {
		if let slot = ui.selected {
			deselect()
			if let cost = sim.marchCost(by: slot, to: xy), cost > 0 {
				return .action(.move(slot, xy))
			}
		}
		if let slot = sim.armyIndex(at: xy) {
			ui.selected = slot
			ui.selectable = sim.reachable(by: slot)
			return .none
		}
		return sim.canAttack(xy) ? .action(.attack(xy)) : .none
	}

	private mutating func deselect() {
		ui.selected = nil
		ui.selectable = nil
	}

	private func build(at xy: XY) -> StrategicReaction {
		sim.canBuild(.fort, at: xy) ? .action(.build(.fort, at: xy)) : .none
	}

	/// C: open the roster of the army on the tile, or muster a new army.
	private func army(at xy: XY) -> StrategicReaction {
		if let slot = sim.armyIndex(at: xy) {
			.events([.army(slot)])
		} else if sim.canFound(at: xy) {
			.action(.found(xy))
		} else {
			.none
		}
	}

	private mutating func toggleMapMode() -> StrategicReaction {
		ui.mapMode = ui.mapMode == .team ? .country : .team
		return .none
	}

	private mutating func handlePan(_ dxy: XY) -> StrategicReaction {
		ui.camera = (ui.camera + dxy).clamped(sim.owner.size)
		return .none
	}
}
