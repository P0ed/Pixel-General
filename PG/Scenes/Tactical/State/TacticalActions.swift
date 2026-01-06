import CoreGraphics

extension TacticalState {

	func vision(for unit: Unit) -> SetXY {
		SetXY(unit.position.circle(2 * 2))
	}

	func vision(for country: Country) -> SetXY {
		units.reduce(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: u)) }
		}
		.union(buildings.flatMap { _, building in
			building.country.team == country.team ? building.position.circle(3) : []
		})
	}

	mutating func selectUnit(_ uid: UID?) {
		if let uid {
			selectedUnit = uid
			cursor = units[uid].position
			selectable = units[uid].canMove ? moves(for: units[uid]).setXY : .none
		} else {
			selectedUnit = .none
			selectable = .none
		}
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
