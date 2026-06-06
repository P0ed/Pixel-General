import CoreGraphics

public enum TacticalAction: Equatable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resupply(UID)
	case purchase(Int, XY)
	case end
}

extension TacticalState {

	public mutating func reduce(_ action: TacticalAction?) -> [TacticalEvent] {
		var events: [TacticalEvent] = []
		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst, into: &events)
		case .move(let unit, let xy): move(unit: unit, to: xy, into: &events)
		case .embark(let u, let t): embark(unit: u, transport: t, into: &events)
		case .disembark(let t, let xy): disembark(unit: t, to: xy, into: &events)
		case .resupply(let u): resupply(unit: u, into: &events)
		case .purchase(let idx, let xy): buy(idx, at: xy, into: &events)
		case .end: endTurn(into: &events)
		case .none: break
		}
		return events
	}

	mutating func resupply(unit id: UID, endOfTurn: Bool = false, into events: inout [TacticalEvent]) {
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
		if endOfTurn, unit[.regen], !unit.isAir || hasBuildings {
			unit.hp.increment(by: 1, cap: unit.maxHP)
		}
		if endOfTurn, !unit.isAir {
			let base = map[position].baseEntrenchment * 4
			unit.ent = min(base + 5 * 4, max(base, unit.ent + unit.entRate))
		}
		unit.ap = endOfTurn ? unit.maxAP : 0
		unit.mp = endOfTurn ? unit.maxMP : 0
		units[id] = unit
		events.append(.update(id))
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
