extension TacticalState {

	static func make(
		player: Player,
		units: [Unit],
		size: Int = .random(in: 24...32),
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings = buildings(player: player, map: map)
		let playerCity = buildings[0].position
		let rusCity = buildings.filter { $0.country == .rus }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero
		let usaCity = buildings.filter { $0.country == .usa }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero
		let sweCity = buildings.filter { $0.country == .swe }.first?.position ?? .zero

		let units: [Unit] = (
			units.mapInPlace { $0.position = $0.position + playerCity }
			+ .base(.usa).mapInPlace { $0.position = $0.position + usaCity - .one }
			+ .base(.rus).mapInPlace { $0.position = $0.position + rusCity - .one }
			+ .small(.swe).mapInPlace { $0.position = $0.position + sweCity - .one }
		)
		.mapInPlace { u in
			u.hp = 0xF
			u.ap = 0b11
			u.ammo = u.maxAmmo
		}

		return TacticalState(
			map: map,
			players: [
				player,
				Player(country: .usa, ai: true, prestige: 0x1F00),
				Player(country: .rus, ai: true, prestige: 0xF00),
				Player(country: .swe, ai: true, prestige: 0x700),
			],
			buildings: buildings,
			units: units
		)
	}

	private static func buildings(player: Player, map: borrowing Map<Terrain>) -> [Building] {
		let cities: [Building] = map.indices.compactMap { xy in
			map[xy] == .city ? Building(country: .swe, position: xy, type: .city) : nil
		}
		let airfields: [Building] = map.indices.compactMap { xy in
			map[xy] == .airfield ? Building(country: .swe, position: xy, type: .airfield) : nil
		}
		var buildings: [Building] = cities.enumerated().map { [cnt = cities.count] i, b in
			modifying(b) { b in
				b.country = i < cnt * 1 / 4 ? player.country
				: i < cnt * 2 / 4 ? .usa
				: i < cnt * 3 / 4 ? .rus
				: .swe
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
