public extension TacticalSim {

	init(new scenario: Scenario) {
		let spawns = scenario.resolvedSpawnPoints
		var map = Map<64, Terrain>(
			seed: scenario.seed,
			players: scenario.players.count,
			terrain: scenario.terrain,
			density: scenario.cityLevel,
			spawns: spawns
		)
		let defending: Team? = scenario.objective.defender
		let cities = Self.cities(
			countries: scenario.players.filter { $0.alive }.map { $0.country },
			defending: defending,
			spawns: spawns,
			map: map
		)
		map.placeForts(
			around: cities.compactMap { xy, c in
				defending.map { team in c.team == team } ?? true ? xy : nil
			},
			level: scenario.fortLevel
		)
		let units = scenario.units.mapInPlace { u in u.reset() }
		let navalCenters = Self.navalCenters(
			players: scenario.players,
			terrain: scenario.terrain,
			cities: cities,
			size: map.size
		)

		self.init(
			map: map,
			players: scenario.players,
			cities: cities,
			units: units,
			navalCenters: navalCenters
		)
		self.objective = scenario.objective
	}

	/// Assign each participating team a distinct terrain sea cell near the
	/// center of mass of its cities, which are also the anchors for its land
	/// deployment. The small exhaustive matching avoids player-order bias when
	/// multiple teams prefer the same sea cell. Returned points are tactical-map
	/// cell centers.
	static func navalCenters(
		players: [Player],
		terrain: [16 of Terrain],
		cities: [(XY, Country)],
		size: Int
	) -> [Team: XY] {
		var teams: [Team] = []
		for player in players where player.alive && player.country.team != .none {
			let team = player.country.team
			if !teams.contains(team) { teams.append(team) }
		}
		let sea = terrain.indices.filter { terrain[$0].isSea }
		guard !teams.isEmpty, !sea.isEmpty else { return [:] }

		func cellCenter(_ index: Int) -> XY {
			XY(terrainIndex: index).cellCenter(size: size)
		}

		let teamCenters = teams.map { team in
			let anchors = cities.compactMap { xy, country in
				country.team == team ? xy : nil
			}
			guard !anchors.isEmpty else { return XY(size / 2, size / 2) }
			return XY(
				anchors.reduce(0) { $0 + $1.x } / anchors.count,
				anchors.reduce(0) { $0 + $1.y } / anchors.count
			)
		}

		let assignmentCount = min(teams.count, sea.count)
		var bestCost = Int.max
		var best: [Int] = []
		func match(_ teamIndex: Int, _ selected: [Int], _ cost: Int) {
			guard teamIndex < assignmentCount else {
				if cost < bestCost {
					bestCost = cost
					best = selected
				}
				return
			}
			for index in sea where !selected.contains(index) {
				let nextCost = cost
					+ cellCenter(index).manhattanDistance(to: teamCenters[teamIndex])
				guard nextCost < bestCost else { continue }
				match(teamIndex + 1, selected + [index], nextCost)
			}
		}
		match(0, [], 0)

		return Dictionary(uniqueKeysWithValues: zip(teams, best).map { team, index in
			(team, cellCenter(index))
		})
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
		self.init(new: Scenario(
			players: players,
			units: units,
			terrain: [16 of Terrain](repeating: terrain),
			fortLevel: forts,
			seed: seed,
			objective: objective
		))
	}

	/// Assign whole city footprints by spawn distance under per-seat quotas
	/// measured in city tiles. Defending seats get double weight.
	private static func cities(
		countries: [Country],
		defending: Team?,
		spawns: [XY],
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

		let centers = spawns.map { $0.cellCenter(size: map.size) }
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
