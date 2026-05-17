extension TacticalUI {

	mutating func apply(_ input: Input, _ s: borrowing TacticalState) -> TacticalAction? {
		return switch input {
		case .direction(let direction?): moveCursor(direction, s)
		case .menu: .menu
		case .action(.a): primaryAction(s)
		case .action(.b): secondaryAction(s)
		case .action(.c): squareAction(s)
		case .action(.d): triangleAction(s)
		case .target(.prev): prevUnit(s)
		case .target(.next): nextUnit(s)
		case .tile(let xy): select(xy, s)
		case .scale(let value): { scale = value; return nil }()
		case .pan(let dxy): handlePan(dxy, s)
		default: nil
		}
	}
}

private extension TacticalUI {

	mutating func select(_ xy: XY, _ s: borrowing TacticalState) -> TacticalAction? {
		guard s.map.contains(xy) else { return nil }

		cursor = xy
		if s.player.type == .human { return primaryAction(s) }
		return nil
	}

	mutating func moveCursor(_ direction: Direction, _ s: borrowing TacticalState) -> TacticalAction? {
		let xy = cursor.neighbor(direction)
		if s.map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func primaryAction(_ s: borrowing TacticalState) -> TacticalAction? {
		if let selectedUnit {
			let unit = s.units[selectedUnit.index]

			if let dst = s.unitAt(cursor), s.player.visible[cursor] {
				if dst.country.team != unit.country.team, s[s.country].type == .human {
					return .attack(selectedUnit, s.unitsMap[cursor])
				} else if s.canEmbark(unit: selectedUnit, transport: s.unitsMap[cursor]), s[s.country].type == .human {
					return .embark(selectedUnit, s.unitsMap[cursor])
				} else {
					selectUnit(dst == unit ? .none : s.unitsMap[cursor], in: s)
				}
			} else if unit.country == s.country, unit.canMove, s[s.country].type == .human {
				return .move(selectedUnit, cursor)
			} else if s.buildings[cursor]?.country == s.country, s[s.country].type == .human {
				return .shop
			} else {
				selectUnit(.none, in: s)
			}
		} else {
			if s.player.visible[cursor], s.unitAt(cursor) != nil {
				selectUnit(s.unitsMap[cursor], in: s)
			} else if s.buildings[cursor]?.country == s.country, s[s.country].type == .human {
				return .shop
			}
		}
		return nil
	}

	mutating func secondaryAction(_ s: borrowing TacticalState) -> TacticalAction? {
		selectUnit(.none, in: s)
		return nil
	}

	mutating func squareAction(_ s: borrowing TacticalState) -> TacticalAction? {
		guard let selectedUnit,
			  s.canDisembark(unit: selectedUnit, to: cursor),
			  s[s.country].type == .human
		else { return nil }
		return .disembark(selectedUnit, cursor)
	}

	mutating func triangleAction(_ s: borrowing TacticalState) -> TacticalAction? {
		guard let selectedUnit,
			  s.units[selectedUnit.index].country == s.country,
			  s.units[selectedUnit.index].untouched,
			  s[s.country].type == .human
		else { return nil }

		selectUnit(.none, in: s)
		return .resupply(selectedUnit)
	}

	mutating func prevUnit(_ s: borrowing TacticalState) -> TacticalAction? {
		nextUnit(s, reversed: true)
	}

	mutating func nextUnit(_ s: borrowing TacticalState, reversed: Bool = false) -> TacticalAction? {
		let cnt = s.units.count
		var idx = selectedUnit?.index ?? (reversed ? cnt - 1 : 0)
		let country = s.country

		for _ in s.units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = s.units[i]

			if u.alive, u.country == country, u.hasActions {
				selectUnit(i.uid, in: s)
				return nil
			}
		}
		selectUnit(nil, in: s)
		return nil
	}

	mutating func handlePan(_ dxy: XY, _ s: borrowing TacticalState) -> TacticalAction? {
		cursor = (cursor + dxy).clamped(s.map.size)
		camera = (camera + dxy).clamped(s.map.size)
		return nil
	}
}
