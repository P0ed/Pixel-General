extension TacticalState {

	func canEmbark(unit: UID, transport: UID) -> Bool {
		let u = units[unit]
		let t = units[transport]
		return u.country == country
		&& t.country == country
		&& u.type == .soft && t[.transport] && u.canMove
		&& u.position.manhattanDistance(to: cursor) == 1
		&& !cargo[transport].alive
	}

	mutating func embark(unit: UID, transport: UID) {
		cargo[transport] = units[unit]
		units[unit].hp = 0x0
		unitsMap[units[unit].position] = -1
		events.add(.move(unit, units[unit].position, units[transport].position))
		selectUnit(units[transport].hasActions ? transport : .none)
	}

	mutating func disembark(unit: UID, to xy: XY) {
		let id = units.add(cargo[unit])
		units[id].position = xy
		units[id].ap &= 0b10
		unitsMap[xy] = id
		cargo[unit].hp = 0x0
		events.add(.spawn(id))
	}
}
