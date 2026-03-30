extension TacticalState {

	static func make(
		players: [4 of Player],
		units: [Unit],
		size: Int = 32,
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		print("Map gen started. Seed: \(seed)")
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
}
