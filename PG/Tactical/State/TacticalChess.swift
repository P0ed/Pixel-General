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
			Unit(country: .swe) >< .strv122,
			Unit(country: .swe) >< .boxer,
			Unit(country: .swe) >< .strf90,
			Unit(country: .swe) >< .pzh,
			Unit(country: .swe) >< .truck,
			Unit(country: .swe) >< .strf90,
			Unit(country: .swe) >< .boxer,
			Unit(country: .swe) >< .strv122,
		]
		+ (0..<8).map { i in Unit(country: .swe) >< .regular }
		+ [
			Unit(country: .isr) >< .strv122,
			Unit(country: .isr) >< .boxer,
			Unit(country: .isr) >< .strf90,
			Unit(country: .isr) >< .truck,
			Unit(country: .isr) >< .pzh,
			Unit(country: .isr) >< .strf90,
			Unit(country: .isr) >< .boxer,
			Unit(country: .isr) >< .strv122,
		]
		+ (0..<8).map { i in Unit(country: .isr) >< .regular }
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
