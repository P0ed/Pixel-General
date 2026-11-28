public struct SupplySources: Equatable, BitwiseCopyable, Monoid {
	public var trucks: SetXY
	public var buildings: SetXY
	public var airfields: SetXY
	public var ports: SetXY
	public var roads: SetXY
	public var hostile: SetXY
	public var enemies: SetXY

	public static var empty: SupplySources {
		SupplySources(
			trucks: .empty,
			buildings: .empty,
			airfields: .empty,
			ports: .empty,
			roads: .empty,
			hostile: .empty,
			enemies: .empty
		)
	}

	public mutating func combine(_ other: SupplySources) {
		trucks.formUnion(other.trucks)
		buildings.formUnion(other.buildings)
		airfields.formUnion(other.airfields)
		ports.formUnion(other.ports)
		roads.formUnion(other.roads)
		hostile.formUnion(other.hostile)
		enemies.formUnion(other.enemies)
	}

	public func level(at xy: XY, terrain: Terrain) -> Int8 {
		Int8(trucks[xy] ? 2 : 0)
		+ terrain.supply
		+ Int8(buildings[xy] ? 2 : 0)
		+ Int8(hostile[xy] ? -1 : 0)
		+ Int8(enemies[xy] ? -2 : roads[xy] ? 1 : 0)
	}

	public func airLevel(at xy: XY) -> Int8 {
		airfields[xy] ? serviceLevel(at: xy) : 0
	}

	public func navalLevel(at xy: XY) -> Int8 {
		ports[xy] ? serviceLevel(at: xy) : 0
	}

	private func serviceLevel(at xy: XY) -> Int8 {
		2 + Int8(trucks[xy] ? 2 : 0) - Int8(enemies[xy] ? 2 : 0)
	}
}

extension Terrain {

	var supply: Int8 {
		switch self {
		case .forest, .rough, .river, .sea: -2
		case .mountain: -3
		default: hasRoad ? 1 : 0
		}
	}
}

public extension TACState {

	func supplySources(for country: Country) -> SupplySources {
		let vision = vision(for: country)
		var sources = SupplySources.empty
		settlements.forEach { xy in
			guard control[xy] == country else { return }
			xy.c5.forEach { n in sources.buildings[n] = true }
			if map[xy] == .airfield {
				xy.c5.forEach { n in sources.airfields[n] = true }
			}
			if map[xy] == .port { sources.ports[xy] = true }
		}
		for xy in map.indices where xy.c5.contains({ xy in map[xy].hasRoad }) {
			sources.roads[xy] = true
		}
		for xy in map.indices where control[xy].team != country.team {
			sources.hostile[xy] = true
		}
		units.forEachAlive { i, u in
			guard !offMap(unit: i.uid) else { return }
			if u.country.team == country.team {
				if u.type == .supply {
					position[i].s9.forEach { n in sources.trucks[n] = true }
				}
			} else if vision[position[i]] {
				position[i].n8.forEach { n in sources.enemies[n] = true }
			}
		}
		return sources
	}

	var humanSupply: SupplySources {
		players.reduce(into: .empty) { r, i, p in
			p.type == .human ? r.combine(supplySources(for: p.country)) : ()
		}
	}
}

extension TACState {

	public func canResupply(unit id: UID) -> Bool {
		let unit = units[id]
		guard unit.country == country, unit.untouched, !offMap(unit: id) else { return false }
		if unit.isNaval {
			let xy = position[id]
			return map[xy] == .port && control[xy] == unit.country
		}
		return !unit.isAir || hasBuildings(near: id)
	}

	mutating func resupply(unit id: UID, endOfTurn: Bool = false, into events: inout [Event]) {
		resupply(unit: id, sources: supplySources(for: units[id].country), endOfTurn: endOfTurn, into: &events)
	}

	mutating func resupply(
		unit id: UID,
		sources: SupplySources,
		endOfTurn: Bool = false,
		into events: inout [Event]
	) {
		var unit = units[id]

		guard endOfTurn
			? unit.country == country && !offMap(unit: id)
			: canResupply(unit: id)
		else { return }

		let xy = position[id.index]
		let (serviced, fed, level) = switch unit.type.moveType {
		case .air: (sources.airfields[xy], sources.airfields[xy], sources.airLevel(at: xy))
		case .naval: (sources.ports[xy], sources.ports[xy], sources.navalLevel(at: xy))
		default: (true, sources.trucks[xy] || sources.buildings[xy], sources.level(at: xy, terrain: map[xy]))
		}

		if unit.maxAmmo > 0, serviced {
			if unit.untouched {
				unit.ammo.increment(by: UInt8(clamping: level + 2), cap: unit.maxAmmo)
			}
			if endOfTurn, fed, !sources.enemies[xy] {
				unit.ammo.increment(by: 1, cap: unit.maxAmmo)
			}
		}
		if serviced, unit.untouched, !endOfTurn {
			let healed = unit.heal(UInt8(clamping: level + 3))
			unit.exp.decrement(by: healed * (unit.lvl + 1))
			self[unit.country].prestige.decrement(by: UInt16(healed) * unit.stats.cost / 32)
		}
		if endOfTurn, unit[.regen], serviced {
			unit.hp.increment(by: 1, cap: unit.maxHP)
		}
		if endOfTurn, !unit.isAir {
			let base = map[xy].baseEntrenchment * 4
			unit.ent = min(base + 5 * 4, max(base, unit.ent + unit.entRate))
		}
		unit.ap = endOfTurn ? unit.maxAP : 0
		unit.mp = endOfTurn ? unit.maxMP : 0
		units[id] = unit
		events.append(.update(id))
	}
}
