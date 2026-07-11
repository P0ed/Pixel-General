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
		Int8(trucks[xy] ? 2 : 0) + Int8(buildings[xy] ? 2 : 0)
		+ terrain.supply - Int8(hostile[xy] ? 1 : 0)
	}
}

extension Terrain {

	var supply: Int8 {
		switch self {
		case .forest, .hill: -1
		case .forestHill, .mountain, .water: -2
		case _ where hasRoad: 1
		default: 0
		}
	}
}

public extension TacticalSim {

	func supplySources(for country: Country) -> SupplySources {
		var sources = SupplySources.empty
		settlements.forEach { xy in
			if map[xy] != .airfield, control[xy] == country {
				xy.c5.forEach { n in sources.buildings[n] = true }
			}
		}
		for xy in map.indices where control[xy].team != country.team {
			sources.hostile[xy] = true
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

	func supply(at xy: XY, for unit: Unit) -> Int8 {
		unit.isAir ? 0 : map[xy].supply
	}

	func canResupply(unit id: UID) -> Bool {
		let unit = units[id]
		return unit.country == country && unit.untouched
			&& !offMap(unit: id)
			&& (!unit.isAir || hasBuildings(near: id))
	}

	mutating func resupply(unit id: UID, endOfTurn: Bool = false, into events: inout [TacticalEvent]) {
		var unit = units[id]

		guard endOfTurn
			? unit.country == country && !offMap(unit: id)
			: canResupply(unit: id)
		else { return }

		let hasBuildings = hasBuildings(near: id)

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
		let supply = UInt8(
			clamping: (noEnemy ? 2 : 1) * ((hasSupply ? 1 : 0) + (hasBuildings ? 1 : 0))
			+ supply(at: position, for: unit)
		)

		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			if unit.untouched {
				unit.ammo.increment(by: supply, cap: unit.maxAmmo)
			}
			if endOfTurn, noEnemy && (hasSupply || hasBuildings) {
				unit.ammo.increment(by: 1, cap: unit.maxAmmo)
			}
		}
		if !unit.isAir || hasBuildings, unit.untouched, !endOfTurn {
			let healed = unit.heal((noEnemy ? 3 : 2) * (supply + 1))
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
