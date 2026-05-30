extension TacticalState {

	var day: Int { Int(turn) / players.count + 1 }

	private var aliveTeams: Set<Team> {
		Set(players.compactMap { _, p in p.alive ? p.country.team : nil })
	}

	mutating func endTurn() {
		captureCities()

		for i in units.indices where units[i].alive && units[i].country == player.country {
			resupply(unit: i.uid, endOfTurn: true)
		}

		guard nextTurn() else { return events.add(.end) }
	}

	private mutating func nextTurn() -> Bool {
		for _ in 0..<players.count {
			turn += 1

			player.visible = vision(for: player.country)

			if playerIndex == 0 {
				player.prestige.increment(by: income(for: player.country))
			}
			if player.alive {
				return aliveTeams.count > 1
			}
		}
		return false
	}

	private func income(for country: Country) -> UInt16 {
		map.indices.reduce(into: 0) { r, xy in
			r += control[xy] == country ? map[xy].income : 0
		}
	}

	func neighbors(at position: XY) -> CArray<8, UID> {
		let n8 = position.n8
		var result = CArray<8, UID>(tail: .none)
		for i in n8.indices {
			let uid = unitsMap[n8[i]]
			if uid != .none { result.add(uid) }
		}
		return result
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
