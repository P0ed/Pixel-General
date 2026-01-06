extension TacticalState {

	static func random(
		player: Player = Player(country: .ukr),
		units: [Unit],
		size: Int = .random(in: 16...32),
		seed: Int = .random(in: 0...1023)
	) -> TacticalState {
		let citiesCount = min(32, size * size / 64)
		let div = size / 8
		let dw = (size - 4) / (div - 1) - 1
		let div2 = citiesCount / div + (citiesCount % div == 0 ? 0 : 1)
		let dh = (size - 2) / (div2 - 1) - 1
		print("citiesCount:", citiesCount, "div:", div, div2, dw, dh)
		let map = Map<Terrain>(size: size, seed: seed)
		let buildings: [Building] = (0 ..< citiesCount).map { i in
			let x = i % div
			let y = (i / div)
			let p = modifying(
				XY(1 + dw * x + 2 * (y & 1), 1 + dh * y)
			) { p in
				if map[p] == .river, let x = p.n8.firstMap({ p in map[p] != .river ? p : nil }) {
					p = x
				}
			}
			return Building(
				country: i == 0 ? player.country
				: i < citiesCount / 2 ? .usa
				: i < citiesCount * 3 / 4 ? .rus
				: .swe,
				position: p,
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
		let sweCity = buildings.filter { $0.country == .swe }.first?.position ?? .zero

		let units: [Unit] = units.mapInPlace { $0.position = $0.position + playerCity }
		+ .base(.usa).mapInPlace { $0.position = $0.position + usaCity - .one }
		+ .base(.rus).mapInPlace { $0.position = $0.position + rusCity - .one }
		+ .small(.swe).mapInPlace { $0.position = $0.position + sweCity - .one }

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
