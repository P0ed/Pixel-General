extension TacticalState {

	static func random(
		player: Player = Player(country: .ukr),
		units: [Unit],
		size: Int = .random(in: 16...32),
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		let citiesCount = min(32, size * size / 64)
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings: [Building] = (0 ..< citiesCount).map { i in
			let p = XY(1 + 8 * (i % (size / 8)), 1 + 8 * (i / (size / 8)))
			let cp = map[p] != .river ? p : p.n8.firstMap { p in map[p] != .river ? p : nil }
			return Building(
				country: i == 0 ? player.country
				: i < citiesCount / 2 ? .usa
				: i < citiesCount * 3 / 4 ? .rus
				: .swe,
				position: cp ?? p,
				type: .city
			)
		}
		let playerCity = buildings[0].position
		let rusCity = buildings.filter { $0.country == .rus }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero
		let usaCity = buildings.filter { $0.country == .usa }.sorted(by: { b1, b2 in
			playerCity.distance(to: b1.position) < playerCity.distance(to: b2.position)
		}).first?.position ?? .zero

		let units: [Unit] = units.mapInPlace { $0.position = $0.position + playerCity }
		+ .base(.usa).mapInPlace { $0.position = $0.position + usaCity }
		+ .base(.rus).mapInPlace { $0.position = $0.position + rusCity }

		return TacticalState(
			map: map,
			players: [
				player,
				Player(country: .usa, ai: true, prestige: 0x600),
				Player(country: .rus, ai: true, prestige: 0x600),
				Player(country: .swe, ai: true, prestige: 0x600),
			],
			buildings: buildings,
			units: units
		)
	}
}
