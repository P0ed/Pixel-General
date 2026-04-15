import CoreGraphics

extension TacticalState {

	func vision(for uid: UID) -> SetXY {
		SetXY(position[uid.index].circle(2 * Int(units[uid.index].spot)))
	}

	func vision(for country: Country) -> SetXY {
		units.reduce(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: i.uid)) }
		}
		.union(buildings.flatMap { _, building in
			building.country.team == country.team ? building.position.circle(3) : []
		})
	}

	mutating func selectUnit(_ uid: UID?) {
		if let uid {
			selectedUnit = uid
			cursor = position[uid.index]
			selectable = units[uid.index].canMove ? moves(for: uid).setXY : .none
		} else {
			selectedUnit = .none
			selectable = .none
		}
	}

	mutating func resupply(unit id: UID) {
		let country = country
		var unit = units[id.index]
		let position = position[id.index]

		guard unit.country == country, unit.untouched else { return }

		let neighbors = neighbors(at: position)

		let noEnemy = !neighbors.contains { n in
			units[n.index].country.team != country.team
		}
		let hasSupply = neighbors.contains { n in
			units[n.index].country.team == country.team
			&& units[n.index][.supply]
		}
		let hasBuildings = buildings.firstMap { _, b in
			b.country == country
			&& (b.type == .airfield) == unit.isAir
			&& b.position.manhattanDistance(to: position) <= 1
			? b : nil
		} != nil
		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			unit.ammo.increment(
				by: (unit.untouched ? (noEnemy ? 2 : 1) : 0) + (hasSupply ? (noEnemy ? 2 : 0) : 0),
				cap: unit.maxAmmo
			)
		}
		if !unit.isAir || hasBuildings {
			unit.healLoosingXP(
				(unit.untouched ? (noEnemy ? 4 : 2) : 0) + (hasSupply ? (noEnemy ? 3 : 1) : 0)
			)
		}
		unit.ap = 0b00
		units[id.index] = unit
	}

	private var tooFarX: Bool { abs(camera.pt.x - cursor.pt.x) > 4.0 * CGFloat(scale) }
	private var tooFarY: Bool { abs(camera.pt.y - cursor.pt.y) > 4.0 * CGFloat(scale) }

	var isCursorTooFar: Bool { tooFarX || tooFarY }

	var reducible: Bool {
		isCursorTooFar || !events.isEmpty || player.type == .ai
	}

	mutating func alignCamera() {
		while tooFarX {
			camera = camera.n8[(camera.pt.x - cursor.pt.x) > 0.0 ? 5 : 1]
		}
		while tooFarY {
			camera = camera.n8[(camera.pt.y - cursor.pt.y) > 0.0 ? 7 : 3]
		}
	}

	mutating func reduce() -> [TacticalEvent] {
		if isCursorTooFar {
			alignCamera()
			return []
		}
		let es = events.map { _, e in e }
		if !es.isEmpty {
			events.erase()
			return es
		}
		if player.type == .ai {
			runAI()
			return []
		}
		return []
	}
}
