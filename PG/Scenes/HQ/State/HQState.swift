struct HQState: ~Copyable {
	var player: Player
	var units: Speicher<16, Unit>
	var events: Speicher<4, HQEvent> = .init(head: [], tail: .none)
	var cursor: XY = .zero
	var selected: UID?
}

extension HQState {

	var inputable: Bool { true }
	var reducible: Bool { !events.isEmpty }

	var statusText: String {
		selected.map { units[$0].status } ?? .makeStatus { add in
			add("prestige: \(player.prestige)")
		}
	}

	mutating func apply(_ input: Input) {
		switch input {
		case .direction(let direction): moveCursor(direction)
		case .action(.a): mainAction()
		case .action(.b): secondaryAction()
		case .action(.c): shopAction()
		case .action(.d): processScenario()
		case .menu: events.add(.new)
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
					units[i].position = units[selected].position
					events.add(.move(i, units[i].position))
				}
				units[selected].position = cursor
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
		if selected == nil, units[cursor] == nil {
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
			u.position = position
		}
		player.prestige.decrement(by: unit.cost)
		events.add(.spawn(units.add(unit)))
	}
}
