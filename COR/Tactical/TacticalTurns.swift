extension TacticalSim {

	public var day: Int { Int(turn) / players.count + 1 }

	var aliveTeams: UInt8 {
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
		captureCities()

		player.prestige.increment(by: income(for: player.country))

		for i in units.indices where units[i].alive && units[i].country == player.country {
			resupply(unit: i.uid, endOfTurn: true, into: &events)
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
			if player.alive {
				vision[playerIndex] = vision(for: player.country)
				return true
			}
		}
		return false
	}

	var winner: Team? {
		let teams = aliveTeams
		return switch objective {
		case .none:
			teams.nonzeroBitCount == 1
			? Team(rawValue: UInt8(teams.trailingZeroBitCount))
			: nil
		case let .survive(team, day: deadline):
			teamAlive(team)
			? (day > deadline ? team : nil)
			: Team(rawValue: UInt8(teams.trailingZeroBitCount))
		}
	}

	private func income(for country: Country) -> UInt16 {
		map.indices.reduce(into: 0) { r, xy in
			r += control[xy] == country ? map[xy].income : 0
		}
	}

	private mutating func captureCities() {
		var reflag = false
		units.forEachAlive { i, u in
			let xy = position[i]
			if map[xy].isSettlement, control[xy].team != u.country.team, !u.isAir {
				control[xy] = u.country
				reflag = true
			}
		}
		if reflag {
			assignControl()
			eliminatePlayers()
		}
	}

	mutating func assignControl() {
		var anchors: [XY] = []
		var owners: [Country] = []
		for xy in map.indices where map[xy].isSettlement {
			anchors.append(xy)
			owners.append(control[xy])
		}
		guard !anchors.isEmpty else { return }

		for xy in map.indices where !map[xy].isSettlement {
			var best = 0
			var bestD = xy.manhattanDistance(to: anchors[0])
			for k in 1 ..< anchors.count {
				let d = xy.manhattanDistance(to: anchors[k])
				if d < bestD { bestD = d; best = k }
			}
			control[xy] = owners[best]
		}
	}

	private mutating func eliminatePlayers() {
		let alive = players.map { i, p in p.alive && countryHasSettlements(p.country) }
		players.modifyEach { i, p in p.alive = alive[i] }
	}

	private func countryHasSettlements(_ country: Country) -> Bool {
		map.indices.contains { xy in map[xy].isSettlement && control[xy] == country }
	}
}
