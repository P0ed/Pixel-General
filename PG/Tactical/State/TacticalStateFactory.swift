extension TacticalState {

	static func make(
		players: [4 of Player],
		units: [Unit],
		size: Int = 32,
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		print("Map gen started. Players: \(players.map { "\($0.country)" }). Seed: \(seed)")
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings: [Building] = buildings(
			players: .init { i in players[i].country },
			map: map
		)
		let playerCity = buildings[0].position
		let firstCity = buildings.filter { $0.country == players[1].country }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero
		let secondCity = buildings.filter { $0.country == players[2].country }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero
		let thirdCity = buildings.filter { $0.country == players[3].country }.first?.position ?? .zero

		let units: [Unit] = (
			units.mapInPlace { $0.position = $0.position + playerCity }
			+ .base(players[1].country).mapInPlace { $0.position = $0.position + firstCity - .one }
			+ .base(players[2].country).mapInPlace { $0.position = $0.position + secondCity - .one }
			+ .base(players[3].country).mapInPlace { $0.position = $0.position + thirdCity - .one }
		)
		.mapInPlace { u in
			u.hp = 0xF
			u.ap = 0b11
			u.ent = UInt8(max(0, map[u.position].def))
			u.ammo = u.maxAmmo
		}

		print("Map gen done. Seed: \(seed)")
		return TacticalState(
			map: map,
			players: players.map(id),
			buildings: buildings,
			units: units
		)
	}

	private static func buildings(players: [4 of Country], map: borrowing Map<Terrain>) -> [Building] {
		let cities: [Building] = map.indices.compactMap { xy in
			map[xy] == .city ? Building(country: .default, position: xy, type: .city) : nil
		}
		let airfields: [Building] = map.indices.compactMap { xy in
			map[xy] == .airfield ? Building(country: .default, position: xy, type: .airfield) : nil
		}
		var buildings: [Building] = cities.enumerated().map { [cnt = cities.count] i, b in
			modifying(b) { b in
				b.country = i < cnt * 1 / 4 ? players[0]
				: i < cnt * 2 / 4 ? players[1]
				: i < cnt * 3 / 4 ? players[2]
				: players[3]
			}
		}
		buildings += airfields.map { b in
			modifying(b) { b in
				b.country = buildings.first { c in (c.position - b.position).manhattan == 1 }
					.map { c in c.country } ?? .swe
			}
		}
		return buildings
	}

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
		+ (0..<8).map { i in Unit(country: .swe, position: XY(i, 1), hp: 0xF) >< .regular }
		+ (0..<8).map { i in Unit(country: .isr, position: XY(i, 6), hp: 0xF) >< .regular }
		+ [
			Unit(country: .swe, position: XY(0, 0), hp: 0xF) >< .strv122,
			Unit(country: .swe, position: XY(7, 0), hp: 0xF) >< .strv122,
			Unit(country: .swe, position: XY(1, 0), hp: 0xF) >< .boxer,
			Unit(country: .swe, position: XY(6, 0), hp: 0xF) >< .boxer,
			Unit(country: .swe, position: XY(2, 0), hp: 0xF) >< .strf90,
			Unit(country: .swe, position: XY(5, 0), hp: 0xF) >< .strf90,
			Unit(country: .swe, position: XY(3, 0), hp: 0xF) >< .pzh,
			Unit(country: .swe, position: XY(4, 0), hp: 0xF) >< .truck,

			Unit(country: .isr, position: XY(0, 7), hp: 0xF) >< .strv122,
			Unit(country: .isr, position: XY(7, 7), hp: 0xF) >< .strv122,
			Unit(country: .isr, position: XY(1, 7), hp: 0xF) >< .boxer,
			Unit(country: .isr, position: XY(6, 7), hp: 0xF) >< .boxer,
			Unit(country: .isr, position: XY(2, 7), hp: 0xF) >< .strf90,
			Unit(country: .isr, position: XY(5, 7), hp: 0xF) >< .strf90,
			Unit(country: .isr, position: XY(4, 7), hp: 0xF) >< .pzh,
			Unit(country: .isr, position: XY(3, 7), hp: 0xF) >< .truck,
		]
		var unitsMap = Map<UID>(size: 8, zero: -1)
		units.enumerated().forEach { i, u in unitsMap[u.position] = i }
		units.modifyEach { u in
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
