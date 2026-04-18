struct HQState: ~Copyable {
	var player: Player
	var units: Speicher<16, Unit>
	var events: CArray<16, HQEvent> = .init(tail: .menu)
	var cursor: XY = .zero
	var selected: UID?
}

extension HQState {

	var reducible: Bool { !events.isEmpty }

	var status: Status {
		Status(
			text: selected.map { units[$0.index].status } ?? .makeStatus { add in
				add("prestige: \(player.prestige)")
			},
			action: .init({
				if selected != nil {
					"sell []"
				} else if units[cursor] == nil {
					"shop []"
				} else {
					""
				}
			}())
		)
	}

	mutating func apply(_ input: Input) -> HQAction? {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction()
		case .action(.d): processScenario()
		case .menu: { events.add(.menu); return .nop }()
		case .tile(let xy): select(xy)
		default: nil
		}
	}

	mutating func select(_ xy: XY) -> HQAction? {
		guard HQNodes.map.contains(xy) else { return nil }

		cursor = xy
		return mainAction()
	}

	mutating func moveCursor(_ direction: Direction) -> HQAction? {
		let xy = cursor.neighbor(direction)
		if HQNodes.map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func mainAction() -> HQAction? {
		if let selected {
			if selected == units[cursor]?.0 {
				self.selected = .none
			} else {
//				if let (i, _) = units[cursor] {
//					units[i.index].position = units[selected.index].position
//					events.add(.move(i, units[i.index].position))
//				}
//				units[selected.index].position = cursor
//				events.add(.move(selected, cursor))
				self.selected = .none
				return .swap(selected.index, cursor.x + cursor.y * 4)
			}
		} else if let (i, _) = units[cursor] {
			selected = i
		}
		return nil
	}

	mutating func secondaryAction() -> HQAction? {
		selected = .none
		return nil
	}

	mutating func shopAction() -> HQAction? {
		if let selected {
			units[selected.index].hp = 0x0
			player.prestige.increment(by: units[selected.index].cost / 2)
			events.add(.remove(selected))
			self.selected = .none
			return .sell(selected.index)
		} else if units[cursor] == nil {
			events.add(.shop)
			return .nop
		}
		return nil
	}

	mutating func processScenario() -> HQAction? {
		events.add(.scenario)
		return .nop
	}
}

extension HQState {

	var country: Country { player.country }

	mutating func buy(_ template: Unit, at position: XY) {
		guard player.prestige >= template.cost, units[position] == nil else { return }

		let unit = modifying(template) { u in
			u.hp = 0xF
		}
		player.prestige.decrement(by: unit.cost)
		events.add(.spawn(units.add(unit).uid))
	}
}
