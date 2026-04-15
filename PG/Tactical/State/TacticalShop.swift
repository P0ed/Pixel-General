extension TacticalState {

	func shopUnits(at xy: XY) -> [Unit] {
		let country = country
		let unitSlots = units.reduce(into: [0, 0] as [2 of Int]) { c, i, u in
			if u.country == country { c[u[.aux] ? 1 : 0] += 1 }
		}

		let core = unitSlots[0] < 16
		let aux = unitSlots[1] < 16

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

	mutating func buy(_ template: Unit, at pos: XY) {
		guard player.prestige >= template.cost, unitsMap[pos] < 0 else { return }

		let unit = modifying(template) { u in
			u.hp = u.maxHP
			u.mp = 0
			u.ap = 0
			u.ammo = u.maxAmmo
		}
		let idx = units.add(unit)
		let id = idx.uid
		unitsMap[pos] = id
		position[idx] = pos
		player.prestige.decrement(by: unit.cost)
		if unit[.aux] {
			let idx = auxilia[playerIndex].firstMap { i, u in u == template ? i : nil }
			if let idx { auxilia[playerIndex].remove(at: idx) }
		}
		events.add(.spawn(id))
	}
}
