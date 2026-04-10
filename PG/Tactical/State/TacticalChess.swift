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
		+ (0..<8).map { i in Unit(country: .swe, position: XY(i, 1)) >< .regular }
		+ (0..<8).map { i in Unit(country: .isr, position: XY(i, 6)) >< .regular }
		+ [
			Unit(country: .swe, position: XY(0, 0)) >< .strv122,
			Unit(country: .swe, position: XY(7, 0)) >< .strv122,
			Unit(country: .swe, position: XY(1, 0)) >< .boxer,
			Unit(country: .swe, position: XY(6, 0)) >< .boxer,
			Unit(country: .swe, position: XY(2, 0)) >< .strf90,
			Unit(country: .swe, position: XY(5, 0)) >< .strf90,
			Unit(country: .swe, position: XY(3, 0)) >< .pzh,
			Unit(country: .swe, position: XY(4, 0)) >< .truck,

			Unit(country: .isr, position: XY(0, 7)) >< .strv122,
			Unit(country: .isr, position: XY(7, 7)) >< .strv122,
			Unit(country: .isr, position: XY(1, 7)) >< .boxer,
			Unit(country: .isr, position: XY(6, 7)) >< .boxer,
			Unit(country: .isr, position: XY(2, 7)) >< .strf90,
			Unit(country: .isr, position: XY(5, 7)) >< .strf90,
			Unit(country: .isr, position: XY(4, 7)) >< .pzh,
			Unit(country: .isr, position: XY(3, 7)) >< .truck,
		]
		var unitsMap = Map<UID>(size: 8, zero: -1)
		units.enumerated().forEach { i, u in unitsMap[u.position] = i.uid }
		units.modifyEach { u in
			u.hp = 0xF
			u.ap = 0b11
			u.ammo = u.maxAmmo
		}

		var state = TacticalState(
			map: map,
			players: .init(head: [players[0], players[1]], tail: .none),
			buildings: .init(
				head: [buildings[0], buildings[1]],
				tail: .empty
			),
			units: .init(head: units, tail: .empty),
			unitsMap: unitsMap,
			cargo: .init(repeating: .empty),
			auxilia: .init { i in .init(tail: .empty) }
		)
		state.players[0].visible = state.vision(for: state.players[0].country)
		state.players[1].visible = state.vision(for: state.players[1].country)

		return state
	}
}
