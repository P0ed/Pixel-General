public extension TacticalSim {

	init(new scenario: Scenario) {
		let players = scenario.players.filter { $0.alive }
		let countries = players.map(\.country)
		let homes = scenario.resolvedSpawnPoints.map { Scenario.inCorner($0, tile: Scenario.quarterCity) }
		var map = Map<64, Terrain>(scenario: scenario)
		let defending = scenario.objective.defender
		let cities = Self.cities(countries: countries, defending: defending, centers: homes, reserveStarts: true, map: map)
		if let defending {
			map.placeForts(
				around: cities.compactMap { xy, country in country.team == defending ? xy : nil },
				level: scenario.fortLevel
			)
		}
		let units = scenario.startingUnits.mapInPlace { $0.reset() }

		self.init(
			map: map,
			players: players,
			cities: cities,
			units: units,
			homes: Dictionary(zip(countries, homes), uniquingKeysWith: { first, _ in first })
		)
		self.objective = scenario.objective
	}

	/// Compatibility factory for standalone battles with one dominant terrain.
	init(
		players: [Player],
		units: [Unit],
		seed: Int,
		terrain: Terrain = .field,
		objective: Objective = .none,
		forts: Int = 0
	) {
		let active = players.filter { $0.alive }
		var d20 = D20(seed: seed)
		let sites = [XY(1, 0), XY(1, 3), XY(3, 1), XY(0, 1), XY(1, 1)]
		let spawns = Array(sites.shuffled(using: &d20).prefix(active.count))
		var map = Map<64, Terrain>(
			seed: seed, terrain: .init(repeating: terrain), density: 0, spawns: spawns
		)
		let cities = Self.cities(
			countries: active.map(\.country), defending: objective.defender,
			centers: spawns.map { $0.cellCenter(size: map.size) }, reserveStarts: false, map: map
		)
		map.placeForts(
			around: cities.compactMap { xy, country in
				objective.defender == nil || country.team == objective.defender ? xy : nil
			},
			level: forts
		)
		let roster = Scenario(players: active, units: units, continents: terrain.isSea).startingUnits
		self.init(map: map, players: active, cities: cities, units: roster.mapInPlace { $0.reset() })
		self.objective = objective
	}

	/// Assign whole city footprints by spawn distance under per-seat quotas
	/// measured in city tiles. Defending seats get double weight.
	private static func cities(
		countries: [Country],
		defending: Team?,
		centers: [XY],
		reserveStarts: Bool,
		map: borrowing Map<64, Terrain>
	) -> [(XY, Country)] {
		guard !countries.isEmpty else { return [] }
		let footprints = map.cityFootprints
		let tileCount = footprints.reduce(0) { $0 + $1.count }
		let weights = countries.map { $0.team == defending ? 2 : 1 }
		let total = weights.reduce(0, +)
		var assignedWeight = 0
		var quotas = weights.map { weight in
			let previousWeight = assignedWeight
			assignedWeight += weight
			return assignedWeight * tileCount / total - previousWeight * tileCount / total
		}

		let distances = footprints.map { city in
			centers.map { center in
				city.map { $0.manhattanDistance(to: center) }.min()!
			}
		}
		var pairs: [(d: Int, p: Int, c: Int)] = []
		for c in footprints.indices {
			for p in countries.indices {
				pairs.append((distances[c][p], p, c))
			}
		}
		pairs.sort { a, b in (a.d, a.p, a.c) < (b.d, b.p, b.c) }

		var owners = [Int?](repeating: nil, count: footprints.count)
		if reserveStarts {
			for (p, home) in centers.enumerated() {
				if let c = footprints.firstIndex(where: { $0.contains(home) }) {
					owners[c] = p
					quotas[p] -= footprints[c].count
				}
			}
		}
		for (_, p, c) in pairs where owners[c] == nil && quotas[p] >= footprints[c].count {
			owners[c] = p
			quotas[p] -= footprints[c].count
		}
		for c in footprints.indices where owners[c] == nil {
			let p = countries.indices.min { a, b in
				(-quotas[a], distances[c][a], a) < (-quotas[b], distances[c][b], b)
			}!
			owners[c] = p
			quotas[p] -= footprints[c].count
		}
		return footprints.indices.flatMap { c in
			footprints[c].map { ($0, countries[owners[c]!]) }
		}.sorted { a, b in
			(a.0.y, a.0.x) < (b.0.y, b.0.x)
		}
	}
}
