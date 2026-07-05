public struct SupplySources: Equatable, BitwiseCopyable, Monoid {
	public var trucks: SetXY
	public var buildings: SetXY

	public static var empty: SupplySources {
		SupplySources(trucks: .empty, buildings: .empty)
	}

	public mutating func combine(_ other: SupplySources) {
		trucks.formUnion(other.trucks)
		buildings.formUnion(other.buildings)
	}

	public func level(at xy: XY) -> UInt8 {
		(trucks[xy] ? 1 : 0) + (buildings[xy] ? 1 : 0)
	}
}

public extension TacticalSim {

	/// Mirrors the ground-unit resupply bonus of `resupply(unit:)`: +1 next
	/// to a friendly-team supply truck, +1 on or next to an owned settlement.
	/// Airfields serve air units only and are not counted.
	func supplySources(for country: Country) -> SupplySources {
		var sources = SupplySources.empty
		for xy in map.indices
		where map[xy].isSettlement && map[xy] != .airfield && control[xy] == country {
			xy.c5.forEach { n in sources.buildings[n] = true }
		}
		units.forEachAlive { i, u in
			guard u.type == .supply, u.country.team == country.team, !offMap(unit: i.uid)
			else { return }
			position[i].n8.forEach { n in sources.trucks[n] = true }
		}
		return sources
	}

	var humanSupply: SupplySources {
		players.reduce(into: .empty) { r, i, p in
			p.type == .human ? r.combine(supplySources(for: p.country)) : ()
		}
	}
}

extension TacticalSim {

	mutating func resupply(unit id: UID, endOfTurn: Bool = false, into events: inout [TacticalEvent]) {
		var unit = units[id]
		let hasBuildings = hasBuildings(near: id)

		guard unit.country == country, unit.untouched || endOfTurn,
			  cargo[id] == .none || unit[.transport],
			  !unit.isAir || hasBuildings || endOfTurn
		else { return }

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
			unit.exp.decrement(by: UInt16(healed) * 4 << unit.lvl)
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
}
