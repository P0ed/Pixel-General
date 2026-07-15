public extension TacticalSim {

	init(
		players: [Player],
		units: [Unit],
		seed: Int,
		terrain: [9 of Terrain],
		objective: Objective = .none,
		forts: Int = 0,
		buildingsMask: [4 of UInt8] = .init(repeating: 0xFF)
	) {
		var map = Map<32, Terrain>(seed: seed, players: players.count, terrain: terrain)
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
			buildingsMask: buildingsMask,
			navalCenters: Self.navalCenters(players: players, terrain: terrain)
		)
		self.objective = objective
	}

	/// Assign each participating team a distinct strategic sea cell, spreading
	/// opposing fleets across the coastline. With two teams, start from the two
	/// most distant cells; additional teams take the cell farthest from those
	/// already selected. The returned points are tactical-map cell centers.
	private static func navalCenters(
		players: [Player],
		terrain: [9 of Terrain]
	) -> [Team: XY] {
		var teams: [Team] = []
		for player in players where player.alive && player.country.team != .none {
			let team = player.country.team
			if !teams.contains(team) { teams.append(team) }
		}
		let sea = terrain.indices.filter { terrain[$0].isSea }
		guard !teams.isEmpty, !sea.isEmpty else { return [:] }

		func distance(_ a: Int, _ b: Int) -> Int {
			abs(a % 3 - b % 3) + abs(a / 3 - b / 3)
		}

		var selected: [Int] = []
		if teams.count == 1 || sea.count == 1 {
			selected.append(sea.min { distance($0, 4) < distance($1, 4) }!)
		} else {
			var pair = (sea[0], sea[1])
			var pairDistance = distance(pair.0, pair.1)
			for i in sea.indices {
				for j in sea.indices where j > i {
					let d = distance(sea[i], sea[j])
					if d > pairDistance {
						pair = (sea[i], sea[j])
						pairDistance = d
					}
				}
			}
			selected = [pair.0, pair.1]
		}
		while selected.count < min(teams.count, sea.count) {
			let next = sea.filter { !selected.contains($0) }.max { a, b in
				selected.map { distance(a, $0) }.min()!
					< selected.map { distance(b, $0) }.min()!
			}!
			selected.append(next)
		}

		return Dictionary(uniqueKeysWithValues: zip(teams, selected).map { team, index in
			let column = index % 3
			let rowFromSouth = 2 - index / 3
			return (team, XY((column * 2 + 1) * 32 / 6, (rowFromSouth * 2 + 1) * 32 / 6))
		})
	}

	/// Compatibility factory for standalone battles with one dominant terrain.
	init(
		players: [Player],
		units: [Unit],
		seed: Int,
		terrain: Terrain = .field,
		objective: Objective = .none,
		forts: Int = 0,
		buildingsMask: [4 of UInt8] = .init(repeating: 0xFF)
	) {
		self.init(
			players: players,
			units: units,
			seed: seed,
			terrain: [9 of Terrain](repeating: terrain),
			objective: objective,
			forts: forts,
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
