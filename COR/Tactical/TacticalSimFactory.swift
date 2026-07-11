public extension TacticalSim {

	init(
		players: [Player],
		units: [Unit],
		size: Int,
		seed: Int,
		terrain: Terrain = .field,
		objective: Objective = .none,
		forts: Int = 0,
		buildingsMask: [4 of UInt8] = .init(repeating: 0xFF)
	) {
		var map = Map<32, Terrain>(size: size, seed: seed, players: players.count, terrain: terrain)
		let defending: Team? = switch objective {
		case .survive(let team, _): team
		case .none: nil
		}
		let cities = Self.cities(
			countries: players.map { p in p.country },
			defending: defending,
			map: map
		)
		// Fort rings guard the defender's cities; without a defending team
		// (sandbox scenarios) every city gets one.
		map.placeForts(
			around: cities.compactMap { xy, c in
				defending.map { team in c.team == team } ?? true ? xy : nil
			},
			level: forts
		)
		let units = units.mapInPlace { u in u.reset() }

		self.init(
			map: map,
			players: players,
			cities: cities,
			units: units,
			buildingsMask: buildingsMask
		)
	}

	private static func cities(
		countries: [Country],
		defending: Team?,
		map: borrowing Map<32, Terrain>
	) -> [(XY, Country)] {
		let cityXYs: [XY] = map.indices.compactMap { xy in
			map[xy] == .city ? xy : nil
		}
		let n = cityXYs.count

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
