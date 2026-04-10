struct HQState: ~Copyable {
	var player: Player
	var units: Speicher<16, Unit>
	var events: CArray<4, HQEvent> = .init(tail: .none)
	var cursor: XY = .zero
	var selected: UID?
}

extension HQState {

	var inputable: Bool { true }
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

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction()
		case .action(.d): processScenario()
		case .menu: events.add(.menu)
		case .tile(let xy): select(xy)
		default: break
		}
	}

	mutating func select(_ xy: XY) {
		guard inputable, HQNodes.map.contains(xy) else { return }

		cursor = xy
		mainAction()
	}

	mutating func moveCursor(_ direction: Direction) {
		let xy = cursor.neighbor(direction)
		if HQNodes.map.contains(xy) { cursor = xy }
	}

	mutating func mainAction() {
		if let selected {
			if selected == units[cursor]?.0 {
				self.selected = .none
			} else {
				if let (i, _) = units[cursor] {
					units[i.index].position = units[selected.index].position
					events.add(.move(i, units[i.index].position))
				}
				units[selected.index].position = cursor
				events.add(.move(selected, cursor))
				self.selected = .none
			}
		} else if let (i, _) = units[cursor] {
			selected = i
		}
	}

	mutating func secondaryAction() {
		selected = .none
	}

	mutating func shopAction() {
		if let selected {
			units[selected.index].hp = 0x0
			player.prestige.increment(by: units[selected.index].cost / 2)
			events.add(.remove(selected))
			self.selected = .none
		} else if units[cursor] == nil {
			events.add(.shop)
		}
	}

	mutating func processScenario() {
		events.add(.scenario)
	}

	mutating func reduce() -> [HQEvent] {
		defer { events.erase() }
		return events.map { $1 }
	}
}

extension HQState {

	var country: Country { player.country }

	mutating func buy(_ template: Unit, at position: XY) {
		guard player.prestige >= template.cost, units[position] == nil else { return }

		let unit = modifying(template) { u in
			u.hp = 0xF
			u.position = position
		}
		player.prestige.decrement(by: unit.cost)
		events.add(.spawn(units.add(unit).uid))
	}
}
