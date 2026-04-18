import CoreGraphics

enum TacticalAction: Hashable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resuply(UID)
	case purchase(Int, XY)
	case end
	case nop
}

extension TacticalState {

	mutating func reduce(_ action: TacticalAction) -> [TacticalEvent] {

		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst)
		case .move(let unit, let xy): move(unit: unit, to: xy)
		case .embark(let u, let t): embark(unit: u, transport: t)
		case .disembark(let t, let xy): disembark(unit: t, to: xy)
		case .resuply(let u): resupply(unit: u)
		case .purchase(let idx, let xy): buy(idx, at: xy)
		case .end: endTurn()
		case .nop: break
		}
		let es = events.map { _, e in e }
		events.erase()
		return es

//		if isCursorTooFar {
//			alignCamera()
//			return []
//		}
//		if player.type == .ai {
//			runAI()
//			return []
//		}
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
		unit.ap = 0
		unit.mp = 0
		units[id.index] = unit
		events.add(.update(id))
	}

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
}
