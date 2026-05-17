extension TacticalState {

	static func chess() -> TacticalState {
		var map = Map<Terrain>(size: 8, zero: .field)
		map.indices.forEach { xy in
			map[xy] = (xy.x + xy.y) % 2 == 0 ? .field : .forest
		}
		let players: [Player] = [
			Player(country: .swe),
			Player(country: .isr),
		]
		let buildings: [Building] = [
			Building(country: .irn, position: XY(4, 0), type: .city),
			Building(country: .isr, position: XY(3, 7), type: .city),
		]
		buildings.indices.forEach { i in map[buildings[i].position] = .city }

		var units: [Unit] = []
		+ [
			.strv122,
			.boxer,
			.strf90,
			.pzh,
			.truck,
			.strf90,
			.boxer,
			.strv122,
		].map { (u: Unit) -> Unit in u.country(.swe) }
		+ (0..<8).map { i in .regular.country(.swe) }
		+ [
			.strv122,
			.boxer,
			.strf90,
			.truck,
			.pzh,
			.strf90,
			.boxer,
			.strv122,
		].map { (u: Unit) -> Unit in u.country(.isr) }
		+ (0..<8).map { i in .regular.country(.isr) }
		let position: [128 of XY] = .init { i in
			XY(i % 8, i < 16 ? i / 8 : 4 + i / 8)
		}

		var unitsMap = Map<UID>(size: 8, zero: -1)
		units.enumerated().forEach { i, u in unitsMap[position[i]] = i.uid }
		units.modifyEach { u in
			u.hp = u.maxHP
			u.ap = u.maxAP
			u.mp = u.maxMP
			u.ammo = u.maxAmmo
		}

		var state = TacticalState(
			map: map,
			players: .init(head: [players[0], players[1]], tail: .none),
			auxilia: .init { i in .init(tail: .empty) },
			buildings: .init(
				head: [buildings[0], buildings[1]],
				tail: .empty
			),
			units: .init(head: units, tail: .empty),
			position: position,
			cargo: .init(repeating: -1),
			unitsMap: unitsMap
		)
		state.players[0].visible = state.vision(for: state.players[0].country)
		state.players[1].visible = state.vision(for: state.players[1].country)

		return state
	}
}
