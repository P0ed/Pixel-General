extension TacticalState {

	func canEmbark(unit: UID, transport: UID) -> Bool {
		let u = units[unit.index]
		let t = units[transport.index]
		return u.country == country
		&& t.country == country
		&& u.type == .soft && t[.transport] && u.canMove
		&& u.position.manhattanDistance(to: cursor) == 1
		&& !cargo[transport.index].alive
	}

	mutating func embark(unit: UID, transport: UID) {
		cargo[transport.index] = units[unit.index]
		units[unit.index].hp = 0x0
		unitsMap[units[unit.index].position] = -1
		events.add(.move(unit, units[unit.index].position, units[transport.index].position))
		selectUnit(units[transport.index].hasActions ? transport : .none)
	}

	mutating func disembark(unit: UID, to xy: XY) {
		let id = units.add(cargo[unit.index])
		units[id].position = xy
		units[id].ap &= units[id][.art] ? 0b00 : 0b10
		unitsMap[xy] = id.uid
		cargo[unit.index].hp = 0x0
		events.add(.spawn(id.uid))
	}
}
