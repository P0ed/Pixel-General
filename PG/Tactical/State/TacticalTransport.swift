extension TacticalState {

	func canEmbark(unit: UID, transport: UID) -> Bool {
		let u = units[unit]
		let up = position[unit.index]
		let t = units[transport]
		let tp = position[transport.index]

		return u.country == country
		&& t.country == country
		&& u.type == .soft && u.canMove && cargo[unit] == .none
		&& t[.transport] && cargo[transport] == .none
		&& up.manhattanDistance(to: tp) == 1
	}

	mutating func embark(unit: UID, transport: UID) {
		guard canEmbark(unit: unit, transport: transport) else { return }
		cargo[transport.index] = unit
		cargo[unit.index] = transport
		let p = position[unit.index]
		let tp = position[transport.index]
		position[unit.index] = tp
		unitsMap[p] = .none
		var path = CArray<16, XY>(head: p, tail: .zero)
		path.add(tp)
		events.add(.move(unit, path))
		if player.type == .human {
			selectUnit(transport)
		}
	}

	func canDisembark(unit: UID, to xy: XY) -> Bool {
		let u = units[unit]

		return u.country == country
		&& u[.transport] && cargo[unit.index] != .none
		&& position[unit.index].manhattanDistance(to: xy) == 1
		&& unitsMap[xy] == .none
	}

	mutating func disembark(unit: UID, to xy: XY) {
		guard canDisembark(unit: unit, to: xy) else { return }
		let idx = cargo[unit.index].index
		let from = position[idx]
		cargo[unit.index] = .none
		cargo[idx] = .none
		position[idx] = xy
		units[idx].mp = 0
		units[idx].ent = 0
		if units[idx][.art] { units[idx].ap = 0 }
		unitsMap[xy] = idx.uid
		player.visible.formUnion(vision(for: idx.uid))
		var path = CArray<16, XY>(head: from, tail: .zero)
		path.add(xy)
		events.add(.move(idx.uid, path))
	}
}
