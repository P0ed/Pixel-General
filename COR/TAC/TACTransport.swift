extension TacticalSim {

	public func canEmbark(unit: UID, transport: UID) -> Bool {
		let u = units[unit]
		let up = position[unit.index]
		let t = units[transport]
		let tp = position[transport.index]

		return u.country == country
		&& t.country == country
		&& (u.transportable || t.type == .cargo && u.isLand)
		&& t[.transport]
		&& (!t.isAir || u[.elite])
		&& u.canMove
		&& cargo[unit] == .none
		&& cargo[transport] == .none
		&& up.manhattanDistance(to: tp) == 1
	}

	mutating func embark(unit: UID, transport: UID, into events: inout [TacticalEvent]) {
		guard canEmbark(unit: unit, transport: transport) else { return }
		let p = position[unit.index]
		let tp = position[transport.index]
		cargo[transport.index] = unit
		cargo[unit.index] = transport
		vacate(unit)
		position[unit.index] = tp
		var path = CArray<16, XY>(head: p, tail: .zero)
		path.add(tp)
		events.append(.move(unit, Path(count: path.count, path: path.mem)))
	}

	public func canDisembark(unit: UID, to xy: XY) -> Bool {
		map.contains(xy)
		&& units[unit].country == country
		&& units[unit][.transport] && cargo[unit.index] != .none
		&& position[unit.index].manhattanDistance(to: xy) == 1
		&& unitsMap[xy] == .none
		&& !map[xy].isWater
	}

	mutating func disembark(unit: UID, to xy: XY, into events: inout [TacticalEvent]) {
		guard canDisembark(unit: unit, to: xy) else { return }
		let idx = cargo[unit.index].index
		let from = position[idx]
		cargo[unit.index] = .none
		cargo[idx] = .none
		place(idx.uid, at: xy)
		units[idx].mp = 0
		units[idx].ent = 0
		if !units[idx].canAttackAfterMove { units[idx].ap = 0 }
		vision[playerIndex].formUnion(vision(for: idx.uid))
		var path = CArray<16, XY>(head: from, tail: .zero)
		path.add(xy)
		events.append(.move(idx.uid, Path(count: path.count, path: path.mem)))
	}
}
