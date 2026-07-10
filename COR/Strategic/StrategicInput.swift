public extension StrategicState {

	mutating func apply(_ input: Input) -> StrategicReaction {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .tile(let xy): select(xy)
		case .action(.a): attack(at: ui.cursor)
		case .action(.b): build(at: ui.cursor)
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
		return attack(at: xy)
	}

	private func attack(at xy: XY) -> StrategicReaction {
		sim.canAttack(xy) ? .action(.attack(xy)) : .none
	}

	private func build(at xy: XY) -> StrategicReaction {
		sim.canBuild(xy) ? .action(.build(xy)) : .none
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
