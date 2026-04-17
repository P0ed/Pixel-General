extension TacticalState {

	mutating func apply(_ input: Input) {
		guard player.type == .human else { return }
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .menu: events.add(.menu)
		case .action(.a): primaryAction()
		case .action(.b): secondaryAction()
		case .action(.c): squareAction()
		case .action(.d): triangleAction()
		case .target(.prev): prevUnit()
		case .target(.next): nextUnit()
		case .tile(let xy): select(xy)
		case .scale(let value): scale = value
		case .pan(let dxy): handlePan(dxy)
		default: break
		}
	}
}

private extension TacticalState {

	mutating func select(_ xy: XY) {
		guard map.contains(xy) else { return }

		cursor = xy
		if player.type == .human { primaryAction() }
	}

	mutating func moveCursor(_ direction: Direction) {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
	}

	mutating func primaryAction() {
		if let selectedUnit {
			let unit = units[selectedUnit.index]

			if let dst = unitAt(cursor), player.visible[cursor] {
				if dst.country.team != unit.country.team {
					action = .attack(selectedUnit, unitsMap[cursor])
				} else if canEmbark(unit: selectedUnit, transport: unitsMap[cursor]) {
					action = .embark(selectedUnit, unitsMap[cursor])
				} else {
					selectUnit(dst == unit ? .none : unitsMap[cursor])
				}
			} else if unit.country == country, unit.canMove {
				action = .move(selectedUnit, cursor)
			} else if buildings[cursor]?.country == country {
				events.add(.shop)
			} else {
				selectUnit(.none)
			}
		} else {
			if player.visible[cursor], unitAt(cursor) != nil {
				selectUnit(unitsMap[cursor])
			} else if buildings[cursor]?.country == country {
				events.add(.shop)
			}
		}
	}

	mutating func secondaryAction() {
		selectUnit(.none)
	}

	mutating func squareAction() {
		guard let selectedUnit, canDisembark(unit: selectedUnit, to: cursor) else { return }
		action = .disembark(selectedUnit, cursor)
	}

	mutating func triangleAction() {
		guard let selectedUnit, units[selectedUnit.index].country == country,
			  units[selectedUnit.index].untouched
		else { return }

		action = .resuply(selectedUnit)
		selectUnit(.none)
	}

	mutating func prevUnit() {
		nextUnit(reversed: true)
	}

	mutating func nextUnit(reversed: Bool = false) {
		let cnt = units.count
		var idx = selectedUnit?.index ?? (reversed ? cnt - 1 : 0)
		let country = country

		for _ in units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = units[i]

			if u.alive, u.country == country, u.hasActions {
				return selectUnit(i.uid)
			}
		}
		selectUnit(nil)
	}

	mutating func handlePan(_ dxy: XY) {
		cursor = (cursor + dxy).clamped(map.size)
		camera = (camera + dxy).clamped(map.size)
	}
}
