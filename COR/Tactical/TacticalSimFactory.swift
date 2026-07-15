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
			navalCenters: Self.navalCenters(
				players: players,
				terrain: terrain,
				cities: cities
			)
		)
		self.objective = objective
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
			let column = index % 3
			let rowFromSouth = 2 - index / 3
			return XY(
				(column * 2 + 1) * 32 / 6,
				(rowFromSouth * 2 + 1) * 32 / 6
			)
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
