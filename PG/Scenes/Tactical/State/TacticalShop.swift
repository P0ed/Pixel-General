extension TacticalState {

	var unitTemplates: [Unit] { .template(country) }

	mutating func buy(_ template: Unit, at position: XY) {
		guard player.prestige >= template.cost, unitsMap[position] < 0 else { return }

		let unit = modifying(template) { u in
			u.position = position
			u.stats.mp = 0
			u.stats.ap = 0
		}
		let id = units.add(unit)
		unitsMap[position] = id
		player.prestige.decrement(by: unit.cost)
		events.add(.spawn(id))
	}
}
