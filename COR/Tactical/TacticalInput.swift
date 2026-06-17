public extension TacticalState {

	mutating func apply(_ input: Input) -> TacticalReaction {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .menu: .events([.menu])
		case .mode: toggleMapMode()
		case .action(.a): primaryAction()
		case .action(.b): secondaryAction()
		case .action(.c): squareAction()
		case .action(.d): triangleAction()
		case .target(.prev): prevUnit()
		case .target(.next): nextUnit()
		case .tile(let xy): select(xy)
		case .scale(let value): { ui.scale = value; return .none }()
		case .pan(let dxy): handlePan(dxy)
		default: .none
		}
	}
}

private extension TacticalState {

	mutating func toggleMapMode() -> TacticalReaction {
		ui.mapMode = ui.mapMode == .terrain ? .political : .terrain
		return .none
	}

	mutating func select(_ xy: XY) -> TacticalReaction {
		guard sim.map.contains(xy) else { return .none }

		ui.cursor = xy
		if sim.player.type == .human { return primaryAction() }
		return .none
	}

	mutating func moveCursor(_ direction: Direction) -> TacticalReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.map.contains(xy) { ui.cursor = xy }
		return .none
	}

	mutating func primaryAction() -> TacticalReaction {
		if ui.selectedUnit != .none {
			let unit = sim.units[ui.selectedUnit]

			if let dst = sim.unitAt(ui.cursor), sim.player.visible[ui.cursor] {
				if dst.country.team != unit.country.team, sim[sim.country].type == .human {
					return .action(.attack(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else if sim.canEmbark(unit: ui.selectedUnit, transport: sim.unitsMap[ui.cursor]), sim[sim.country].type == .human {
					return .action(.embark(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else {
					ui.select(dst == unit ? .none : sim.unitsMap[ui.cursor], in: sim)
				}
			} else if unit.country == sim.country, unit.canMove, sim[sim.country].type == .human {
				return .action(.move(ui.selectedUnit, ui.cursor))
			} else if sim.map[ui.cursor].isSettlement, sim.control[ui.cursor] == sim.country, sim.player.type == .human {
				return .events([.shop])
			} else {
				ui.select(.none, in: sim)
			}
		} else {
			if sim.player.visible[ui.cursor], sim.unitAt(ui.cursor) != nil {
				ui.select(sim.unitsMap[ui.cursor], in: sim)
			} else if sim.map[ui.cursor].isSettlement, sim.control[ui.cursor] == sim.country, sim.player.type == .human {
				return .events([.shop])
			}
		}
		return .none
	}

	mutating func secondaryAction() -> TacticalReaction {
		ui.select(.none, in: sim)
		return .none
	}

	mutating func squareAction() -> TacticalReaction {
		guard ui.selectedUnit != .none,
			  sim.canDisembark(unit: ui.selectedUnit, to: ui.cursor),
			  sim[sim.country].type == .human
		else { return .none }
		return .action(.disembark(ui.selectedUnit, ui.cursor))
	}

	mutating func triangleAction() -> TacticalReaction {
		guard ui.selectedUnit != .none,
			  sim.units[ui.selectedUnit].country == sim.country,
			  sim.units[ui.selectedUnit].untouched,
			  sim[sim.country].type == .human
		else { return .none }

		defer { ui.select(.none, in: sim) }
		return .action(.resupply(ui.selectedUnit))
	}

	mutating func prevUnit() -> TacticalReaction {
		nextUnit(reversed: true)
	}

	mutating func nextUnit(reversed: Bool = false) -> TacticalReaction {
		let cnt = sim.units.count
		var idx = ui.selectedUnit != .none ? ui.selectedUnit.index : (reversed ? cnt - 1 : 0)
		let country = sim.country

		for _ in sim.units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = sim.units[i]

			if u.alive, !sim.offMap(unit: i.uid), u.country == country, u.hasActions {
				ui.select(i.uid, in: sim)
				return .none
			}
		}
		ui.select(.none, in: sim)
		return .none
	}

	mutating func handlePan(_ dxy: XY) -> TacticalReaction {
		ui.cursor = (ui.cursor + dxy).clamped(sim.map.size)
		ui.camera = (ui.camera + dxy).clamped(sim.map.size)
		return .none
	}
}
