extension TacticalState {

	var inputable: Bool { !player.ai }

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction): moveCursor(direction)
		case .menu: events.add(.menu)
		case .action(.a): primaryAction()
		case .action(.b): secondaryAction()
		case .action(.c): endTurn()
		case .action(.d): events.add(.gameOver)
		case .target(.prev): prevUnit()
		case .target(.next): nextUnit()
		case .tile(let xy): select(xy)
		case .scale(let value): scale = value
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
		if let selectedID = selectedUnit {
			let unit = units[selectedID]

			if let (dstID, dst) = units[cursor] {
				if dst.country.team != unit.country.team {
					attack(src: selectedID, dst: dstID)
				} else {
					selectUnit(dst == unit ? .none : dstID)
				}
			} else if unit.canMove {
				move(unit: selectedID, to: cursor)
			} else if buildings[cursor]?.country == country {
				events.add(.shop)
			} else {
				selectUnit(.none)
			}
		} else {
			if let (i, u) = units[cursor], u.country == country {
				selectUnit(i)
			} else if buildings[cursor]?.country == country {
				events.add(.shop)
			}
		}
	}

	mutating func secondaryAction() {
		selectUnit(.none)
	}

	mutating func prevUnit() {
		nextUnit(reversed: true)
	}

	mutating func nextUnit(reversed: Bool = false) {
		var idx = selectedUnit ?? (reversed ? units.count - 1 : 0)
		let country = country

		for _ in units.indices {
			let u = units[idx % units.count]
			if u.alive, u.country == country, u.hasActions {
				return selectUnit(idx)
			}
			idx += reversed ? -1 : 1
		}
		selectUnit(nil)
	}
}
