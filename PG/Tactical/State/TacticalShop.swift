extension TacticalState {

	func shopUnits(at xy: XY) -> [Unit] {
		let country = country
		let slots = units.reduce(into: [0, 0] as [2 of Int]) { c, i, u in
			if u.country == country { c[u[.aux] ? 1 : 0] += 1 }
		}
		let core = slots[0] < 16
		let aux = slots[1] < 16

		return buildings[xy].map { b in
			.make { units in
				let isAir = b.type == .airfield
				if core {
					units += .shop(country: country, filterAir: isAir)
				}
				if aux {
					units += auxilia[playerIndex]
						.compactMap { i, u in u.isAir == isAir ? u : nil }
				}
			}
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
		if unit[.aux] {
			let idx = auxilia[playerIndex].firstMap { i, u in u == template ? i : nil }
			if let idx { auxilia[playerIndex].remove(at: idx) }
		}
		events.add(.spawn(id))
	}
}
