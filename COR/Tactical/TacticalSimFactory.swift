public extension TacticalSim {

	init(new scenario: Scenario) {
		let spawns = scenario.resolvedSpawnPoints
		var map = Map<32, Terrain>(
			seed: scenario.seed,
			players: scenario.players.count,
			terrain: scenario.terrain,
			density: scenario.cityLevel,
			spawns: spawns
		)
		let defending: Team? = scenario.objective.defender
		let cities = Self.cities(
			countries: scenario.players.map { p in p.country },
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

		self.init(
			map: map,
			players: scenario.players,
			cities: cities,
			units: units,
			buildingsMask: scenario.buildingsMask,
			navalCenters: Self.navalCenters(
				players: scenario.players,
				terrain: scenario.terrain,
				cities: cities
			)
		)
		self.objective = scenario.objective
	}

	/// Assign each participating team a distinct strategic sea cell near the
	/// center of mass of its cities, which are also the anchors for its land
	/// deployment. The small exhaustive matching avoids player-order bias when
	/// multiple teams prefer the same sea cell. Returned points are tactical-map
	/// cell centers.
	static func navalCenters(
		players: [Player],
		terrain: [9 of Terrain],
		cities: [(XY, Country)]
	) -> [Team: XY] {
		var teams: [Team] = []
		for player in players where player.alive && player.country.team != .none {
			let team = player.country.team
			if !teams.contains(team) { teams.append(team) }
		}
		let sea = terrain.indices.filter { terrain[$0].isSea }
		guard !teams.isEmpty, !sea.isEmpty else { return [:] }

		func strategicCenter(_ index: Int) -> XY {
			XY(index % 3, 2 - index / 3).cellCenter(size: 32)
		}

		let teamCenters = teams.map { team in
			let anchors = cities.compactMap { xy, country in
				country.team == team ? xy : nil
			}
			guard !anchors.isEmpty else { return XY(16, 16) }
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
					+ strategicCenter(index).manhattanDistance(to: teamCenters[teamIndex])
				guard nextCost < bestCost else { continue }
				match(teamIndex + 1, selected + [index], nextCost)
			}
		}
		match(0, [], 0)

		return Dictionary(uniqueKeysWithValues: zip(teams, best).map { team, index in
			(team, strategicCenter(index))
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
		self.init(new: Scenario(
			players: players,
			units: units,
			terrain: [9 of Terrain](repeating: terrain),
			fortLevel: forts,
			seed: seed,
			objective: objective,
			buildingsMask: buildingsMask
		))
	}

	/// Settlement ownership. With `spawns` present each seat's share of the
	/// cities clusters around its spawn cell: cities go greedily to the
	/// nearest spawn under per-seat quotas, so counts keep the defender
	/// weighting and duplicate spawns still split their cluster. Without
	/// spawns the legacy index-proportional slicing applies.
	private static func cities(
		countries: [Country],
		defending: Team?,
		spawns: [XY],
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

		guard spawns.count == countries.count, !spawns.isEmpty else {
			return cityXYs.enumerated().map { i, xy in
				let pos = i * total / n
				let idx = thresholds.firstIndex { pos < $0 } ?? countries.count - 1
				return (xy, countries[idx])
			}
		}

		let centers = spawns.map { s in s.cellCenter(size: map.size) }
		var quotas = thresholds.enumerated().map { idx, t in
			t * n / total - (idx > 0 ? thresholds[idx - 1] : 0) * n / total
		}
		var pairs: [(d: Int, p: Int, c: Int)] = []
		for c in cityXYs.indices {
			for p in countries.indices {
				pairs.append((cityXYs[c].manhattanDistance(to: centers[p]), p, c))
			}
		}
		pairs.sort { a, b in (a.d, a.p, a.c) < (b.d, b.p, b.c) }

		var owner = [Int?](repeating: nil, count: n)
		for pair in pairs where owner[pair.c] == nil && quotas[pair.p] > 0 {
			owner[pair.c] = pair.p
			quotas[pair.p] -= 1
		}
		return cityXYs.enumerated().map { i, xy in
			(xy, countries[owner[i] ?? countries.count - 1])
		}
	}
}
