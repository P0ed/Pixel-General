import CoreGraphics

enum TacticalAction: Equatable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resupply(UID)
	case purchase(Int, XY)
	case shop
	case menu
	case end
}

extension TacticalState {

	mutating func reduce(_ action: TacticalAction?, ui: inout TacticalUI) -> [TacticalEvent] {
		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst, ui: &ui)
		case .move(let unit, let xy): move(unit: unit, to: xy, ui: &ui)
		case .embark(let u, let t): embark(unit: u, transport: t, ui: &ui)
		case .disembark(let t, let xy): disembark(unit: t, to: xy)
		case .resupply(let u): resupply(unit: u)
		case .purchase(let idx, let xy): buy(idx, at: xy)
		case .shop: events.add(.shop)
		case .menu: events.add(.menu)
		case .end: endTurn()
		case .none: break
		}
		defer { events.erase() }
		return events.map { _, e in e }
	}

	func hasBuildings(near id: UID) -> Bool {
		let u = units[id.index]
		let p = position[id.index]
		return buildings.firstMap { _, b in
			b.country == u.country
			&& (b.type == .airfield) == u.isAir
			&& b.position.manhattanDistance(to: p) <= 1
			? b : nil
		} != nil
	}

	mutating func resupply(unit id: UID) {
		guard cargo[id.index] == -1 || units[id.index][.transport], units[id.index].untouched else { return }

		let country = country
		var unit = units[id.index]
		let position = position[id.index]

		guard unit.country == country, unit.untouched else { return }

		let neighbors = neighbors(at: position)

		let noEnemy = !neighbors.contains { n in
			units[n.index].country.team != country.team
		}
		let hasSupply = neighbors.contains { n in
			units[n.index].country.team == country.team
			&& units[n.index][.supply]
		}
		let hasBuildings = hasBuildings(near: id)
		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			unit.ammo.increment(
				by: (unit.untouched ? (noEnemy ? 2 : 1) : 0) + (hasSupply ? (noEnemy ? 2 : 0) : 0),
				cap: unit.maxAmmo
			)
		}
		if !unit.isAir || hasBuildings {
			unit.healLoosingXP(
				(unit.untouched ? (noEnemy ? 4 : 2) : 0) + (hasSupply ? (noEnemy ? 3 : 1) : 0)
			)
		}
		unit.ap = 0
		unit.mp = 0
		units[id.index] = unit
		events.add(.update(id))
	}

	mutating func regen(unit id: UID) {
		guard units[id.index][.regen], !units[id.index].isAir || hasBuildings(near: id) else { return }
		units[id.index].hp.increment(by: 1, cap: units[id.index].maxHP)
	}

	mutating func rest(unit id: UID) {
		units[id.index] = modifying(units[id.index]) { u in
			u.ap = u.maxAP
			u.mp = u.maxMP
		}
	}

	mutating func entrench(unit id: UID) {
		if units[id.index].isAir { return }
		units[id.index].ent = min(7, max(
			map[position[id.index]].baseEntrenchment,
			units[id.index].ent + 1
		))
	}

	func vision(for uid: UID) -> SetXY {
		SetXY(position[uid.index].circle(2 * Int(units[uid.index].spot)))
	}

	func vision(for country: Country) -> SetXY {
		units.reduce(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: i.uid)) }
		}
		.union(buildings.flatMap { _, building in
			building.country.team == country.team ? building.position.circle(3) : []
		})
	}

}
