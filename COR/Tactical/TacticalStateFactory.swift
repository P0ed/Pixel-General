public extension TacticalState {

	static func make(
		players: [Player],
		units: [Unit],
		size: Int,
		seed: Int
	) -> TacticalState {
		print("Map gen started. Players: \(players.map { "\($0.country)" }). Seed: \(seed)")
		let map = Map<32, Terrain>(size: size, seed: seed, players: players.count)
		let cities: [(XY, Country)] = cities(
			countries: players.map { p in p.country },
			map: map
		)
		let units: [Unit] = (
			units
			+ (players.count > 1 ? .base(players[1].country) : [])
			+ (players.count > 2 ? .base(players[2].country) : [])
			+ (players.count > 3 ? .base(players[3].country) : [])
		)
		.mapInPlace { u in u.reset() }

		print("Map gen done. Seed: \(seed) size: \(size)")
		return TacticalState(
			map: map,
			players: players,
			cities: cities,
			units: units
		)
	}

	private static func cities(countries: [Country], map: borrowing Map<32, Terrain>) -> [(XY, Country)] {
		let cityXYs: [XY] = map.indices.compactMap { xy in
			map[xy] == .city ? xy : nil
		}
		let n = cityXYs.count
		return cityXYs.enumerated().map { i, xy in
			let c: Country = switch countries.count {
			case 4: i < n * 1 / 4 ? countries[0]
				: i < n * 2 / 4 ? countries[1]
				: i < n * 3 / 4 ? countries[2]
				: countries[3]
			case 3: i < n * 1 / 3 ? countries[0]
				: i < n * 2 / 3 ? countries[1]
				: countries[2]
			case 2: i < n * 1 / 2 ? countries[0] : countries[1]
			default: fatalError()
			}
			return (xy, c)
		}
	}
}

public extension TacticalSim {

	/// Whether any player of `team` is still alive — used to decide the victor of
	/// a campaign battle once the `.end` condition (one team remaining) is met.
	func teamAlive(_ team: Team) -> Bool {
		players.firstMap { _, p in p.alive && p.country.team == team ? true : nil } ?? false
	}
}
