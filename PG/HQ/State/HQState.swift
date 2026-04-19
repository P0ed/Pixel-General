struct HQState: ~Copyable {
	var player: Player
	var units: [16 of Unit]
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

	mutating func purchase(_ idx: Int, in slot: Int) {
		let template = shop[idx]
		guard player.prestige >= template.cost, !units[slot].alive else { return }

		let unit = modifying(template) { u in
			u.hp = 0xF
		}
		player.prestige.decrement(by: unit.cost)
		units[slot] = unit
		events.add(.spawn(slot.uid))
	}
}
