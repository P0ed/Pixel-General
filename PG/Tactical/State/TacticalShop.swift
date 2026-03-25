extension TacticalState {

	func shopUnits(at xy: XY) -> [Unit] {
		buildings[xy].map { b in
			.shop(country: country, filterAir: b.type == .airfield)
		} ?? []
	}

	mutating func buy(_ template: Unit, at position: XY) {
		guard player.prestige >= template.cost, unitsMap[position] < 0 else { return }

		let unit = modifying(template) { u in
			u.position = position
			u.ap = 0b00
			u.ammo = u.maxAmmo
		}
		let id = units.add(unit)
		unitsMap[position] = id
		player.prestige.decrement(by: unit.cost)
		events.add(.spawn(id))
	}
}
