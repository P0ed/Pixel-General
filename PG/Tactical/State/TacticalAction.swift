import CoreGraphics

enum TacticalAction: Equatable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resupply(UID)
	case purchase(Int, XY)
	case end
}

extension TacticalState {

	mutating func reduce(_ action: TacticalAction?) -> [TacticalEvent] {
		if let action { print("reduce \(action)") }
		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst)
		case .move(let unit, let xy): move(unit: unit, to: xy)
		case .embark(let u, let t): embark(unit: u, transport: t)
		case .disembark(let t, let xy): disembark(unit: t, to: xy)
		case .resupply(let u): resupply(unit: u)
		case .purchase(let idx, let xy): buy(idx, at: xy)
		case .end: endTurn()
		case .none: break
		}
		defer { events.erase() }
		return events.map { _, e in e }
	}

	func hasBuildings(near id: UID) -> Bool {
		let u = units[id.index]
		let p = position[id.index]
		return map.indices.contains { xy in
			map[xy].isBuilding
			&& control[xy] == u.country
			&& (map[xy] == .airfield) == u.isAir
			&& xy.manhattanDistance(to: p) <= 1
		}
	}

	mutating func resupply(unit id: UID, endOfTurn: Bool = false) {
		guard units[id.index].country == country && units[id.index].untouched || endOfTurn,
			  cargo[id.index] == -1 || units[id.index][.transport]
		else { return }

		var unit = units[id.index]
		let country = unit.country
		let position = position[id.index]
		let neighbors = neighbors(at: position)

		let noEnemy = !neighbors.contains { n in
			units[n.index].country.team != country.team
		}
		let hasSupply = neighbors.contains { n in
			units[n.index].country.team == country.team
			&& units[n.index][.supply]
		}
		let hasBuildings = hasBuildings(near: id)
		let supply: UInt8 = (hasSupply ? 1 : 0) + (hasBuildings ? 1 : 0)

		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			if unit.untouched {
				unit.ammo.increment(
					by: (noEnemy ? 2 : 1) * (supply + 1),
					cap: unit.maxAmmo
				)
			}
			if endOfTurn {
				unit.ammo.increment(
					by: noEnemy && supply > 0 ? 1 : 0,
					cap: unit.maxAmmo
				)
			}
		}
		if !unit.isAir || hasBuildings, unit.untouched, !endOfTurn {
			let healCap: UInt8 = (noEnemy ? 3 : 2) * (supply + 1)
			let healed = unit.heal(healCap)
			unit.exp.decrement(by: UInt16(healed) * 3 << unit.lvl)
			self[unit.country].prestige.decrement(by: UInt16(healed) * unit.cost / 32)
		}
		if endOfTurn, units[id.index][.regen], !units[id.index].isAir || hasBuildings {
			units[id.index].hp.increment(by: 1, cap: units[id.index].maxHP)
		}
		if endOfTurn, !unit.isAir {
			let base = map[position].baseEntrenchment * 4
			unit.ent = min(base + 5 * 4, max(base, unit.ent + unit.entRate))
		}
		unit.ap = endOfTurn ? unit.maxAP : 0
		unit.mp = endOfTurn ? unit.maxMP : 0
		units[id.index] = unit
		events.add(.update(id))
	}

	func vision(for uid: UID) -> SetXY {
		SetXY(position[uid.index].circle(2 * Int(units[uid.index].spot)))
	}

	func vision(for country: Country) -> SetXY {
		var v = units.reduce(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: i.uid)) }
		}
		for xy in map.indices where map[xy].isBuilding && control[xy].team == country.team {
			v = v.union(xy.circle(3))
		}
		return v
	}

	mutating func selectUnit(_ uid: UID?) {
		if let uid {
			selectedUnit = uid
			cursor = position[uid.index]
			selectable = units[uid.index].canMove ? moves(for: uid).setXY : .none
		} else {
			selectedUnit = .none
			selectable = .none
		}
	}
}
