extension TacticalState {

	static func make(
		players: [Player],
		units: [Unit],
		size: Int,
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		print("Map gen started. Players: \(players.map { "\($0.country)" }). Seed: \(seed)")
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings: [Building] = buildings(
			countries: players.map { p in p.country },
			map: map
		)
		let units: [Unit] = (
			units
			+ (players.count > 1 ? .base(players[1].country) : [])
			+ (players.count > 2 ? .base(players[2].country) : [])
			+ (players.count > 3 ? .base(players[3].country) : [])
		)
		.mapInPlace { u in
			u.hp = u.maxHP
			u.ap = u.maxAP
			u.mp = u.maxMP
			u.ammo = u.maxAmmo
			u.ent = 0
		}

		print("Map gen done. Seed: \(seed) size: \(size)")
		return TacticalState(
			map: map,
			players: players,
			buildings: buildings,
			units: units
		)
	}

	private static func buildings(countries: [Country], map: borrowing Map<Terrain>) -> [Building] {
		let cities: [Building] = map.indices.compactMap { xy in
			map[xy] == .city ? Building(country: .default, position: xy, type: .city) : nil
		}
		let airfields: [Building] = map.indices.compactMap { xy in
			map[xy] == .airfield ? Building(country: .default, position: xy, type: .airfield) : nil
		}
		var buildings: [Building] = cities.enumerated().map { [cities = cities.count] i, b in
			modifying(b) { b in
				b.country = switch countries.count {
				case 4: i < cities * 1 / 4 ? countries[0]
					: i < cities * 2 / 4 ? countries[1]
					: i < cities * 3 / 4 ? countries[2]
					: countries[3]
				case 3: i < cities * 1 / 3 ? countries[0]
					: i < cities * 2 / 3 ? countries[1]
					: countries[2]
				case 2: i < cities * 1 / 2 ? countries[0] : countries[1]
				default: fatalError()
				}
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
