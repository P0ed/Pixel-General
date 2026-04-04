extension TacticalState {

	var inputable: Bool { player.type == .human }

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .menu: events.add(.menu)
		case .action(.a): primaryAction()
		case .action(.b): secondaryAction()
		case .action(.c): squareAction()
		case .action(.d): endTurn()
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
		guard inputable, map.contains(xy) else { return }

		cursor = xy
		primaryAction()
	}

	mutating func moveCursor(_ direction: Direction) {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
	}

	mutating func primaryAction() {
		if let selectedUnit {
			let unit = units[selectedUnit]

			if let dst = unitAt(cursor), player.visible[cursor] {
				if dst.country.team != unit.country.team {
					attack(src: selectedUnit, dst: unitsMap[cursor])
				} else if canEmbark(unit: selectedUnit, transport: unitsMap[cursor]) {
					embark(unit: selectedUnit, transport: unitsMap[cursor])
				} else {
					selectUnit(dst == unit ? .none : unitsMap[cursor])
				}
			} else if unit.country == country, unit.canMove {
				move(unit: selectedUnit, to: cursor)
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
		guard let selectedUnit, units[selectedUnit].country == country,
			  units[selectedUnit][.transport], cargo[selectedUnit].alive,
			  units[selectedUnit].position.manhattanDistance(to: cursor) == 1,
			  unitsMap[cursor] == -1
		else { return }

		disembark(unit: selectedUnit, to: cursor)
	}

	mutating func prevUnit() {
		nextUnit(reversed: true)
	}

	mutating func nextUnit(reversed: Bool = false) {
		let cnt = units.count
		var idx = selectedUnit ?? (reversed ? cnt - 1 : 0)
		let country = country

		for _ in units.indices {
			idx += reversed ? -1 : 1
			let uid = (cnt + idx) % cnt
			let u = units[uid]

			if u.alive, u.country == country, u.hasActions {
				return selectUnit(uid)
			}
		}
		selectUnit(nil)
	}

	mutating func handlePan(_ dxy: XY) {
		cursor = (cursor + dxy).clamped(map.size)
		camera = (camera + dxy).clamped(map.size)
	}
}
