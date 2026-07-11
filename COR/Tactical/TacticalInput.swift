public extension TacticalState {

	mutating func apply(_ input: Input) -> TacticalReaction {

		defer {
			ui.selectable = ui.selectedUnit != .none && sim.units[ui.selectedUnit].canMove
			? sim.moves(for: ui.selectedUnit).setXY : nil
		}

		return switch input {
		case .direction(let direction?, modifiers: let modifiers):
			directionalAction(direction, modifiers: modifiers)
		case .menu: .events([.menu])
		case .mode: toggleMapMode()
		case .action(let action?, modifiers: let modifiers):
			buttonAction(action, modifiers: modifiers)
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

	mutating func directionalAction(
		_ direction: Direction,
		modifiers: InputModifiers
	) -> TacticalReaction {
		if modifiers.contains(.right) { return zoom(direction) }
		if modifiers.contains(.left) { return moveCamera(direction) }
		return moveCursor(direction)
	}

	mutating func buttonAction(
		_ action: Action,
		modifiers: InputModifiers
	) -> TacticalReaction {
		if modifiers.contains(.right) { return setMapMode(action) }
		return switch action {
		case .a: primaryAction()
		case .b: secondaryAction()
		case .c: squareAction()
		case .d: triangleAction()
		}
	}

	mutating func setMapMode(_ action: Action) -> TacticalReaction {
		switch action {
		case .a: ui.mapMode = .terrain
		case .b: ui.mapMode = ui.mapMode == .country ? .team : .country
		case .c: ui.mapMode = .supply
		case .d: break
		}
		return .none
	}

	mutating func zoom(_ direction: Direction) -> TacticalReaction {
		switch direction {
		case .up: ui.scale = max(1, ui.scale / 2)
		case .down: ui.scale = min(4, ui.scale * 2)
		case .left, .right: break
		}
		return .none
	}

	mutating func moveCamera(_ direction: Direction) -> TacticalReaction {
		ui.camera = (ui.camera.neighbor(direction)).clamped(sim.map.size)
		return .none
	}

	mutating func toggleMapMode() -> TacticalReaction {
		ui.mapMode = switch ui.mapMode {
		case .terrain: .supply
		case .supply: .country
		case .country: .team
		case .team: .terrain
		}
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
		let playerCountry = sim.country
		let playerType = sim[playerCountry].type

		if ui.selectedUnit != .none {
			let unit = sim.units[ui.selectedUnit]
			let unitCountry = unit.country

			if let dst = sim.unitAt(ui.cursor), sim.vision[sim.playerIndex][ui.cursor] {
				if playerType == .human, unitCountry == playerCountry, dst.country.team != unitCountry.team {
					return .action(.attack(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else if sim.canEmbark(unit: ui.selectedUnit, transport: sim.unitsMap[ui.cursor]), playerType == .human {
					return .action(.embark(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else {
					ui.selectedUnit = dst == unit ? .none : sim.unitsMap[ui.cursor]
				}
			} else if unitCountry == playerCountry, unit.canMove, playerType == .human {
				return .action(.move(ui.selectedUnit, ui.cursor))
			} else if sim.map[ui.cursor].isSettlement, sim.control[ui.cursor] == playerCountry, playerType == .human {
				return .events([.shop])
			} else {
				ui.selectedUnit = .none
			}
		} else {
			if sim.vision[sim.playerIndex][ui.cursor], sim.unitAt(ui.cursor) != nil {
				ui.selectedUnit = sim.unitsMap[ui.cursor]
			} else if sim.map[ui.cursor].isSettlement, sim.control[ui.cursor] == playerCountry, playerType == .human {
				return .events([.shop])
			}
		}
		return .none
	}

	mutating func secondaryAction() -> TacticalReaction {
		ui.selectedUnit = .none
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

		defer { ui.selectedUnit = .none }
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
				ui.selectedUnit = i.uid
				ui.cursor = sim.position[i]
				return .none
			}
		}
		ui.selectedUnit = .none
		return .none
	}

	mutating func handlePan(_ dxy: XY) -> TacticalReaction {
		ui.camera = (ui.camera + dxy).clamped(sim.map.size)
		return .none
	}
}
