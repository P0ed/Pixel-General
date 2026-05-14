extension TacticalState {

	var day: Int { Int(turn) / players.count + 1 }

	private var aliveTeams: Set<Team> {
		Set(players.compactMap { _, p in p.alive ? p.country.team : nil })
	}

	mutating func endTurn() {
		captureCities()

		guard nextTurn() else { return events.add(.end) }
	}

	private mutating func nextTurn() -> Bool {
		for _ in 0..<players.count {
			turn += 1
			if playerIndex == 0 { startNextDay() }
			if player.alive {
				return aliveTeams.count > 1
			}
		}
		return false
	}

	private mutating func startNextDay() {
		let ps = players.map { _, p in
			guard p.alive else { return p }
			return modifying(p) { p in endTurn(player: &p) }
		}
		players.modifyEach { i, p in p = ps[i] }

		for i in units.indices where units[i].alive {
			endTurn(unit: i.uid)
		}
	}

	private func income(for player: Player) -> UInt16 {
		buildings.reduce(into: 0) { r, _, b in
			r += b.country == player.country ? b.income : 0
		}
	}

	private func endTurn(player: inout Player) {
		player.visible = vision(for: player.country)
		player.prestige.increment(by: income(for: player))
	}

	private mutating func endTurn(unit id: UID) {
		regen(unit: id)
		entrench(unit: id)
		resupply(unit: id)
		rest(unit: id)
	}

	func neighbors(at position: XY) -> CArray<8, UID> {
		let n8 = position.n8
		var result = CArray<8, UID>(tail: -1)
		for i in n8.indices {
			let uid = unitsMap[n8[i]]
			if uid != -1 { result.add(uid) }
		}
		return result
	}

	private mutating func captureCities() {
		let reflag = units.reduce(into: false) { reflag, i, u in

			let idx = buildings.firstMap { j, b in
				b.position == position[i] ? j : nil
			}

			if let idx, buildings[idx].country.team != u.country.team, !u.isAir {
				buildings[idx].country = u.country
				reflag = true
			}
		}
		if reflag {
			eliminatePlayers()
		}
	}

	private mutating func eliminatePlayers() {
		let alive = players.map { i, p in p.alive && countryHasCities(p.country) }
		players.modifyEach { i, player in player.alive = alive[i] }
	}

	private func countryHasCities(_ country: Country) -> Bool {
		buildings.firstMap { _, b in
			b.type == .city && b.country == country ? true : nil
		} ?? false
	}
}
