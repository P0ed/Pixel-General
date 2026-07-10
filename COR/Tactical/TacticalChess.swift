public extension TacticalSim {

	static func chess() -> TacticalSim {
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
			Unit(model: .strv122, country: .swe),
			Unit(model: .boxer, country: .swe),
			Unit(model: .strf90, country: .swe),
			Unit(model: .pzh, country: .swe),
			Unit(model: .truck, country: .swe),
			Unit(model: .strf90, country: .swe),
			Unit(model: .boxer, country: .swe),
			Unit(model: .strv122, country: .swe),
		]
		+ (0..<8).map { i in Unit(model: .regular, country: .swe) }
		+ [
			Unit(model: .strv122, country: .isr),
			Unit(model: .boxer, country: .isr),
			Unit(model: .strf90, country: .isr),
			Unit(model: .truck, country: .isr),
			Unit(model: .pzh, country: .isr),
			Unit(model: .strf90, country: .isr),
			Unit(model: .boxer, country: .isr),
			Unit(model: .strv122, country: .isr),
		]
		+ (0..<8).map { i in Unit(model: .regular, country: .isr) }
		units.modifyEach { u in u.reset() }

		var control = Map<32, Country>(size: 8, zero: .default)
		cityPlacements.forEach { xy, c in control[xy] = c }
		for xy in map.indices where map[xy] != .city {
			control[xy] = cityPlacements.min { a, b in
				xy.manhattanDistance(to: a.0) < xy.manhattanDistance(to: b.0)
			}.map { $0.1 } ?? .default
		}

		var sim = TacticalSim(
			map: map,
			control: control,
			unitsMap: Map<32, UID>(size: 8, zero: .none),
			players: .init(head: [players[0], players[1]], tail: .none),
			vision: .init(repeating: .empty),
			units: .init(head: units, tail: .empty),
			position: .init(repeating: .zero),
			cargo: .init(repeating: .none)
		)
		sim.indexSettlements()
		for i in units.indices {
			sim.place(i.uid, at: XY(i % 8, i < 16 ? i / 8 : 4 + i / 8))
		}
		sim.vision[0] = sim.vision(for: sim.players[0].country)
		sim.vision[1] = sim.vision(for: sim.players[1].country)

		return sim
	}
}
