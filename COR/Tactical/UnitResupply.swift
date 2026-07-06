public struct SupplySources: Equatable, BitwiseCopyable, Monoid {
	public var trucks: SetXY
	public var buildings: SetXY
	public var hostile: SetXY

	public static var empty: SupplySources {
		SupplySources(trucks: .empty, buildings: .empty, hostile: .empty)
	}

	public mutating func combine(_ other: SupplySources) {
		trucks.formUnion(other.trucks)
		buildings.formUnion(other.buildings)
		hostile.formUnion(other.hostile)
	}

	public func level(at xy: XY, terrain: Terrain) -> Int8 {
		Int8(trucks[xy] ? 2 : 0) + Int8(buildings[xy] ? 3 : 0)
		- Int8(terrain.supplyPenalty) - Int8(hostile[xy] ? 1 : 0)
	}
}

extension Terrain {

	var supplyPenalty: UInt8 {
		switch self {
		case .forest, .hill: 1
		case .forestHill, .mountain, .water: 2
		default: 0
		}
	}
}

public extension TacticalSim {

	func supplySources(for country: Country) -> SupplySources {
		var sources = SupplySources.empty
		for xy in map.indices {
			if map[xy].isSettlement, map[xy] != .airfield, control[xy] == country {
				xy.c5.forEach { n in sources.buildings[n] = true }
			}
			if control[xy].team != country.team {
				sources.hostile[xy] = true
			}
		}
		units.forEachAlive { i, u in
			guard u.type == .supply, u.country.team == country.team, !offMap(unit: i.uid)
			else { return }
			position[i].s9.forEach { n in sources.trucks[n] = true }
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

	func supplyPenalty(at xy: XY, for unit: Unit) -> UInt8 {
		(unit.isAir ? 0 : map[xy].supplyPenalty)
		+ (control[xy].team != unit.country.team ? 1 : 0)
	}

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
		let penalty = supplyPenalty(at: position, for: unit)

		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			if unit.untouched {
				var restock = (noEnemy ? 2 : 1) * (supply + 1)
				restock.decrement(by: penalty)
				unit.ammo.increment(by: restock, cap: unit.maxAmmo)
			}
			if endOfTurn {
				unit.ammo.increment(
					by: noEnemy && supply > penalty ? 1 : 0,
					cap: unit.maxAmmo
				)
			}
		}
		if !unit.isAir || hasBuildings, unit.untouched, !endOfTurn {
			var healCap: UInt8 = (noEnemy ? 3 : 2) * (supply + 1)
			healCap.decrement(by: penalty)
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
