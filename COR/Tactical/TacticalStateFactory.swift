public extension TacticalState {

	init(
		players: [Player],
		objective: Objective = .none,
		units: [Unit],
		size: Int,
		seed: Int
	) {
		print("Map gen started. Players: \(players.map { "\($0.country)" }). Seed: \(seed)")
		let map = Map<32, Terrain>(size: size, seed: seed, players: players.count)
		let cities: [(XY, Country)] = Self.cities(
			countries: players.map { p in p.country },
			objective: objective,
			map: map
		)
		let units: [Unit] = (
			units
			+ (players.count > 1 ? .base(players[1].country, lvl: players[1].baseLevel) : [])
			+ (players.count > 2 ? .base(players[2].country, lvl: players[2].baseLevel) : [])
			+ (players.count > 3 ? .base(players[3].country, lvl: players[3].baseLevel) : [])
		)
		.mapInPlace { u in u.reset() }

		print("Map gen done. Seed: \(seed) size: \(size)")
		self = TacticalState(
			map: map,
			players: players,
			cities: cities,
			units: units
		)
	}

	private static func cities(
		countries: [Country],
		objective: Objective,
		map: borrowing Map<32, Terrain>
	) -> [(XY, Country)] {
		let cityXYs: [XY] = map.indices.compactMap { xy in
			map[xy] == .city ? xy : nil
		}
		let n = cityXYs.count

		let defending: Team? = switch objective {
		case .survive(let team, _): team
		case .none: nil
		}
		let weights = countries.map { $0.team == defending ? 2 : 1 }
		let total = weights.reduce(0, +)
		let thresholds = weights.reduce(into: [Int]()) { acc, w in
			acc.append((acc.last ?? 0) + w)
		}

		return cityXYs.enumerated().map { i, xy in
			let pos = i * total / n
			let idx = thresholds.firstIndex { pos < $0 } ?? countries.count - 1
			return (xy, countries[idx])
		}
	}
}
