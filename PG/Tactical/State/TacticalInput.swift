extension TacticalState {

	mutating func apply(_ input: Input) -> TacticalAction? {
		guard player.type == .human else { return nil }
		return switch input {
		case .direction(let direction?): moveCursor(direction)
		case .menu: { events.add(.menu); return nil }()
		case .action(.a): primaryAction()
		case .action(.b): secondaryAction()
		case .action(.c): squareAction()
		case .action(.d): triangleAction()
		case .target(.prev): prevUnit()
		case .target(.next): nextUnit()
		case .tile(let xy): select(xy)
		case .scale(let value): { scale = value; return nil }()
		case .pan(let dxy): handlePan(dxy)
		default: nil
		}
	}
}

private extension TacticalState {

	mutating func select(_ xy: XY) -> TacticalAction? {
		guard map.contains(xy) else { return nil }

		cursor = xy
		if player.type == .human { return primaryAction() }
		return nil
	}

	mutating func moveCursor(_ direction: Direction) -> TacticalAction? {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func primaryAction() -> TacticalAction? {
		if let selectedUnit {
			let unit = units[selectedUnit.index]

			if let dst = unitAt(cursor), player.visible[cursor] {
				if dst.country.team != unit.country.team {
					return .attack(selectedUnit, unitsMap[cursor])
				} else if canEmbark(unit: selectedUnit, transport: unitsMap[cursor]) {
					return .embark(selectedUnit, unitsMap[cursor])
				} else {
					selectUnit(dst == unit ? .none : unitsMap[cursor])
				}
			} else if unit.country == country, unit.canMove {
				return .move(selectedUnit, cursor)
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
		return nil
	}

	mutating func secondaryAction() -> TacticalAction? {
		selectUnit(.none)
		return nil
	}

	mutating func squareAction() -> TacticalAction? {
		guard let selectedUnit, canDisembark(unit: selectedUnit, to: cursor) else { return nil }
		return .disembark(selectedUnit, cursor)
	}

	mutating func triangleAction() -> TacticalAction? {
		guard let selectedUnit, units[selectedUnit.index].country == country,
			  units[selectedUnit.index].untouched
		else { return nil }

		selectUnit(.none)
		return .resuply(selectedUnit)
	}

	mutating func prevUnit() -> TacticalAction? {
		nextUnit(reversed: true)
	}

	mutating func nextUnit(reversed: Bool = false) -> TacticalAction? {
		let cnt = units.count
		var idx = selectedUnit?.index ?? (reversed ? cnt - 1 : 0)
		let country = country

		for _ in units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = units[i]

			if u.alive, u.country == country, u.hasActions {
				selectUnit(i.uid)
				return nil
			}
		}
		selectUnit(nil)
		return nil
	}

	mutating func handlePan(_ dxy: XY) -> TacticalAction? {
		cursor = (cursor + dxy).clamped(map.size)
		camera = (camera + dxy).clamped(map.size)
		return nil
	}
}
