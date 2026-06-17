extension TacticalSim {

	public var day: Int { Int(turn) / players.count + 1 }

	var aliveTeams: UInt8 {
		players.reduce(into: 0) { r, _, p in
			if p.alive {
				r |= 1 << p.country.team.rawValue
			}
		}
	}

	mutating func endTurn(into events: inout [TacticalEvent]) {
		captureCities()

		for i in units.indices where units[i].alive && units[i].country == player.country {
			resupply(unit: i.uid, endOfTurn: true, into: &events)
		}

		guard nextTurn() else { return events.append(.end) }
	}

	private mutating func nextTurn() -> Bool {
		for _ in 0..<players.count {
			turn += 1

			player.visible = vision(for: player.country)

			if playerIndex == 0 {
				player.prestige.increment(by: income(for: player.country))
			}
			if player.alive {
				return aliveTeams.nonzeroBitCount > 1
			}
		}
		return false
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

	private mutating func eliminatePlayers() {
		let alive = players.map { i, p in p.alive && countryHasSettlements(p.country) }
		players.modifyEach { i, player in player.alive = alive[i] }
	}

	private func countryHasSettlements(_ country: Country) -> Bool {
		map.indices.contains { xy in map[xy].isSettlement && control[xy] == country }
	}
}
