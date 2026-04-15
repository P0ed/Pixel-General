extension TacticalState {

	func canEmbark(unit: UID, transport: UID) -> Bool {
		let u = units[unit.index]
		let up = position[unit.index]
		let t = units[transport.index]
		let tp = position[transport.index]
		return u.country == country
		&& t.country == country
		&& u.type == .soft && u.canMove && !u[.cargo]
		&& t[.transport] && cargo[transport.index] == -1
		&& up.manhattanDistance(to: tp) == 1
	}

	mutating func embark(unit: UID, transport: UID) {
		cargo[transport.index] = unit
		units[unit.index][.cargo] = true
		let p = position[unit.index]
		let tp = position[transport.index]
		unitsMap[p] = -1
		events.add(.move(unit, p, tp))
		selectUnit(transport)
	}

	func canDisembark(unit: UID, to xy: XY) -> Bool {
		let u = units[unit.index]
		return u.country == country
		&& u[.transport] && cargo[unit.index] != -1
		&& position[unit.index].manhattanDistance(to: xy) == 1
		&& unitsMap[xy] == -1
	}

	mutating func disembark(unit: UID, to xy: XY) {
		let idx = cargo[unit.index].index
		cargo[unit.index] = -1
		position[idx] = xy
		units[idx].mp = 0
		units[idx][.cargo] = false
		if units[idx][.art] { units[idx].ap = 0 }
		unitsMap[xy] = idx.uid
		player.visible.formUnion(vision(for: idx.uid))
		events.add(.spawn(idx.uid))
	}
}
