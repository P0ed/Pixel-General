extension TacticalState {

	static func make(
		players: [4 of Player],
		units: [Unit],
		size: Int = 32,
		seed: Int = .random(in: 0...31)
	) -> TacticalState {
		print("Map gen started. Players: \(players.map { "\($0.country)" }). Seed: \(seed)")
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings: [Building] = buildings(
			players: .init { i in players[i].country },
			map: map
		)
		let units: [Unit] = (
			units
			+ .base(players[1].country)
			+ .base(players[2].country)
			+ .base(players[3].country)
		)
		.mapInPlace { u in
			u.hp = u.maxHP
			u.ap = u.maxAP
			u.mp = u.maxMP
			u.ammo = u.maxAmmo
			u.ent = 0
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
}
