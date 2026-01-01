import CoreGraphics

extension TacticalState {

	func vision(for unit: Unit) -> SetXY {
		let range = switch unit.stats.unitType {
		case .aa: 3
		case .fighter: 2
		default: 1
		}
		return SetXY(unit.position.circle(range * 3))
	}

	func vision(for country: Country) -> SetXY {
		units.reduce(into: SetXY.empty) { v, i, u in
			if u.country == country { v.formUnion(vision(for: u)) }
		}
		.union(buildings.flatMap { _, building in
			building.country == country ? building.position.circle(3) : []
		})
	}

	mutating func selectUnit(_ uid: UID?) {
		if let uid {
			selectedUnit = uid
			cursor = units[uid].position
			selectable = units[uid].canMove ? moves(for: units[uid]) : .none
		} else {
			selectedUnit = .none
			selectable = .none
		}
	}

	func moves(for unit: Unit) -> SetXY {
		!unit.canMove ? .empty : .make { xys in
			if unit.stats.moveType == .air {
				xys = .init(unit.position.circle(Int(unit.stats.mov) * 2))
			} else {
				var front: [(XY, UInt8)] = [(unit.position, unit.stats.mov)]
				let team = unit.country.team
				repeat {
					front = front.flatMap { from, mp in

						func landEnemy(at xy: XY) -> Bool {
							units[xy].map { _, u in
								u.country.team != team && u.stats.moveType != .air
							} ?? false
						}
						let enemies = from.n4.reduce(into: 0 as UInt8) { r, xy in
							if landEnemy(at: xy) { r += 1 }
						}
						return from.n8.compactMap { (xy: XY) -> (XY, UInt8)? in
							if landEnemy(at: xy) {
								return .none
							}
							if (xy - from).manhattan == 2,
							   landEnemy(at: XY(from.x, xy.y)),
							   landEnemy(at: XY(xy.x, from.y))
							{
								return .none
							}

							let moveCost = map[xy].moveCost(unit.stats) + enemies
							if !xys[xy] && moveCost <= mp {
								return (xy, mp - moveCost)
							}
							return .none
						}
					}
					xys.formUnion(SetXY(front.map { pos, _ in pos }))
				} while !front.isEmpty
			}
		}
		.subtracting(units.map { _, u in u.position })
	}

	mutating func move(unit uid: UID, to position: XY) {
		guard units[uid].alive, units[uid].country == country,
			  units[uid].canMove, moves(for: units[uid])[position]
		else { return }

		let distance = units[uid].position.distance(to: position)
		units[uid].position = position
		units[uid].stats.mp = 0
		units[uid].stats.ent = 0
		if units[uid].stats.unitType == .art { units[uid].stats.ap = 0 }

		let vision = vision(for: units[uid])
		player.visible.formUnion(vision)
		selectUnit(units[uid].hasActions ? uid : .none)
		events.add(.move(uid, distance))
	}

	private var tooFarX: Bool { abs(camera.pt.x - cursor.pt.x) > 4.0 * scale }
	private var tooFarY: Bool { abs(camera.pt.y - cursor.pt.y) > 4.0 * scale }

	var isCursorTooFar: Bool { tooFarX || tooFarY }

	var reducible: Bool {
		isCursorTooFar || !events.isEmpty || player.ai
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
		if player.ai {
			runAI()
			return []
		}
		return []
	}
}
