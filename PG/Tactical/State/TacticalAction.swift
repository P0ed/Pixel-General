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
		let u = units[id]
		let p = position[id.index]
		return map.indices.contains { xy in
			map[xy].isSettlement
			&& control[xy] == u.country
			&& (map[xy] == .airfield) == u.isAir
			&& xy.manhattanDistance(to: p) <= 1
		}
	}

	mutating func resupply(unit id: UID, endOfTurn: Bool = false) {
		guard units[id].country == country && units[id].untouched || endOfTurn,
			  cargo[id] == .none || units[id][.transport]
		else { return }

		var unit = units[id]
		let country = unit.country
		let position = position[id.index]
		let neighbors = neighbors(at: position)

		let noEnemy = !neighbors.contains { n in
			units[n].country.team != country.team
		}
		let hasSupply = neighbors.contains { n in
			units[n].country.team == country.team
			&& units[n].type == .supply
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
		if endOfTurn, units[id][.regen], !units[id].isAir || hasBuildings {
			units[id].hp.increment(by: 1, cap: units[id].maxHP)
		}
		if endOfTurn, !unit.isAir {
			let base = map[position].baseEntrenchment * 4
			unit.ent = min(base + 5 * 4, max(base, unit.ent + unit.entRate))
		}
		unit.ap = endOfTurn ? unit.maxAP : 0
		unit.mp = endOfTurn ? unit.maxMP : 0
		units[id] = unit
		events.add(.update(id))
	}

	func vision(for id: UID) -> SetXY {
		vision(at: position[id], spot: units[id].spot)
	}

	func vision(at pos: XY, spot: UInt8) -> SetXY {
		.make { v in
			v[pos] = true
			switch spot {
			case 3: pos.n36.forEach { xy in v[xy] = true }
			default: pos.n20.forEach { xy in v[xy] = true }
			}
		}
	}

	func vision(for country: Country) -> SetXY {
		var v = units.reduceAlive(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: i.uid)) }
		}
		for xy in map.indices where map[xy].isSettlement && control[xy].team == country.team {
			v[xy] = true
			xy.n8.forEach { xy in v[xy] = true }
		}
		return v
	}

	mutating func selectUnit(_ uid: UID) {
		selectedUnit = uid
		if uid != .none {
			cursor = position[uid]
			selectable = units[uid].canMove ? moves(for: uid).setXY : .none
		} else {
			selectable = .none
		}
	}
}
