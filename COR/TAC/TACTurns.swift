extension TacticalSim {

	public var day: Int { Int(turn) / players.count + 1 }

	public var aliveTeams: UInt8 {
		players.reduce(into: 0) { r, _, p in
			if p.alive {
				r |= 1 << p.country.team.rawValue
			}
		}
	}

	func teamAlive(_ team: Team) -> Bool {
		aliveTeams & 1 << team.rawValue != 0
	}

	mutating func endTurn(into events: inout [TacticalEvent]) {
		let captor = captureCities()
		assignControl()
		updateSurvivingTeams()
		refreshVision()

		player.prestige.increment(by: income(for: player.country))

		let sources = supplySources(for: player.country)
		for i in units.indices where units[i].alive && units[i].country == player.country {
			units[i].armOverwatch()
			resupply(unit: i.uid, sources: sources, endOfTurn: true, into: &events)
		}

		if let defender = objective.defender, let captor, !hasCity(for: defender) {
			objective = Objective(capturedBy: captor)
			return events.append(.end)
		}
		guard nextTurn() else { return events.append(.end) }
	}

	private mutating func nextTurn() -> Bool {
		if aliveTeams.nonzeroBitCount <= 1 { return false }

		for _ in 0..<players.count {
			turn += 1
			if case let .survive(_, day: deadline) = objective, day > deadline {
				return false
			}
			if player.alive { return true }
		}
		return false
	}

	public var winner: Team? {
		if let winner = objective.captureWinner { return winner }
		let teams = aliveTeams
		if teams.nonzeroBitCount == 1 {
			return Team(rawValue: UInt8(teams.trailingZeroBitCount))
		}
		guard case let .survive(team, day: deadline) = objective, day > deadline,
			teamAlive(team), hasCity(for: team) else { return nil }
		return team
	}

	private func hasCity(for team: Team) -> Bool {
		settlements.firstMap { xy in map[xy] == .city && control[xy].team == team ? xy : nil } != nil
	}

	private func income(for country: Country) -> UInt16 {
		settlements.reduce(into: 0) { r, xy in
			r += control[xy] == country ? map[xy].income : 0
		}
	}

	private mutating func captureCities() -> Team? {
		let defender = objective.defender
		var captor: Team?
		units.forEachAlive { i, u in
			guard !u.isAir, !u.type.isNaval, !offMap(unit: i.uid) else { return }
			let xy = position[i]
			if map[xy] == .city, control[xy].team != u.country.team {
				if control[xy].team == defender { captor = u.country.team }
				control[xy] = u.country
			}
		}
		return captor
	}

	private mutating func updateSurvivingTeams() {
		let cityTeams: UInt8 = settlements.reduce(into: 0) { mask, xy in
			if map[xy] == .city {
				mask |= 1 << control[xy].team.rawValue
			}
		}
		players.modifyEach { _, p in
			p.alive = p.alive && cityTeams & (1 << p.country.team.rawValue) != 0
		}
	}

	mutating func assignControl() {
		var visited = SetXY.empty
		var frontier = CArray<4096, XY>(tail: .zero)
		settlements.forEach { xy in
			guard map[xy] == .city else { return }
			visited[xy] = true
			frontier.add(xy)
		}
		guard !frontier.isEmpty else {
			control = .init(zero: .none)
			return
		}

		// A four-neighbor flood expands by Manhattan distance. The row-major
		// seed order gives the earlier city first claim on each equal-distance tile.
		var head = 0
		while head < frontier.count {
			let xy = frontier[head]
			let owner = control[xy]
			head += 1
			for neighbor in xy.n4 where map.contains(neighbor) && !visited[neighbor] {
				visited[neighbor] = true
				control[neighbor] = owner
				frontier.add(neighbor)
			}
		}
	}
}

extension Terrain {

	var income: UInt16 {
		switch self {
		case .city: 24
		case .airfield: 4
		default: 0
		}
	}
}
