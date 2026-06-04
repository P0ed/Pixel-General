public extension TacticalState {

	static func chess() -> TacticalState {
		var map = Map<32, Terrain>(size: 8, zero: .field)
		map.indices.forEach { xy in
			map[xy] = (xy.x + xy.y) % 2 == 0 ? .field : .forest
		}
		let players: [Player] = [
			Player(country: .swe),
			Player(country: .isr),
		]
		let cityPlacements: [(XY, Country)] = [
			(XY(4, 0), .irn),
			(XY(3, 7), .isr),
		]
		cityPlacements.forEach { xy, _ in map[xy] = .city }

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

		var unitsMap = Map<32, UID>(size: 8, zero: .none)
		units.enumerated().forEach { i, u in unitsMap[position[i]] = i.uid }
		units.modifyEach { u in u.reset() }

		var control = Map<32, Country>(size: 8, zero: .default)
		cityPlacements.forEach { xy, c in control[xy] = c }
		for xy in map.indices where map[xy] != .city {
			control[xy] = cityPlacements.min { a, b in
				xy.manhattanDistance(to: a.0) < xy.manhattanDistance(to: b.0)
			}.map { $0.1 } ?? .default
		}

		var state = TacticalState(
			map: map,
			control: control,
			unitsMap: unitsMap,
			players: .init(head: [players[0], players[1]], tail: .none),
			auxilia: .init { i in .init(tail: .empty) },
			units: .init(head: units, tail: .empty),
			position: position,
			cargo: .init(repeating: .none)
		)
		state.players[0].visible = state.vision(for: state.players[0].country)
		state.players[1].visible = state.vision(for: state.players[1].country)

		return state
	}
}
