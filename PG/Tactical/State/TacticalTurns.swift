extension TacticalState {

	var day: Int { Int(turn) / players.count + 1 }

	private var aliveTeams: Set<Team> {
		Set(players.map { _, p in p.country.team })
	}

	mutating func endTurn() {
		captureCities()

		guard nextTurn() else { return events.add(.gameOver) }

		resetUI()
	}

	private mutating func nextTurn() -> Bool {
		for _ in 0..<players.count {
			turn += 1
			if playerIndex == 0 { startNextDay() }
			if player.alive {
				return players.firstMap { _, p in p.type != .ai ? () : nil } != nil
			}
		}
		return false
	}

	private mutating func startNextDay() {
		let ps = Dictionary(uniqueKeysWithValues: players.map { i, p in
			(i, modifying(p) { p in endTurn(player: &p) })
		})
		players.modifyEach { i, p in
			p = ps[i] ?? p
		}
		for i in units.indices where units[i].alive {
			endTurn(unit: i.uid)
		}
		events.add(.nextDay)
	}

	private func income(for player: Player) -> UInt16 {
		buildings.reduce(into: 0) { r, _, b in
			r += b.country == player.country ? b.income : 0
		}
	}

	private mutating func resetUI() {
		selectUnit(.none)

		cursor = units.firstMap { [country] i, u in
			u.country == country ? position[i] : nil
		}
		?? buildings.firstMap { [country] _, b in
			b.country == country ? b.position : nil
		}
		?? .zero

		camera = cursor
	}

	private func endTurn(player: inout Player) {
		player.visible = vision(for: player.country)
		player.prestige.increment(by: income(for: player))
	}

	private mutating func endTurn(unit id: UID) {
		var unit = units[id.index]
		let neighbors = neighbors(at: position[id.index])

		let hasSupply = neighbors.contains { n in
			units[n.index].country.team == unit.country.team
			&& units[n.index][.supply]
		}
		if !unit.isAir {
			unit.ent.increment(
				by: (unit.canMove ? 1 : 0) + (hasSupply ? 1 : 0),
				cap: 7
			)
		}
		if !unit[.cargo], unit.untouched { resupply(unit: id) }
		unit.ap = unit.maxAP
		unit.mp = unit.maxMP
		units[id.index] = unit
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
		let alive = Dictionary(uniqueKeysWithValues: players.map { i, p in
			(i, countryHasCities(p.country))
		})
		players.modifyEach { i, player in
			player.alive = alive[i] ?? false
		}
	}

	private func countryHasCities(_ country: Country) -> Bool {
		buildings.firstMap { _, b in
			b.type == .city && b.country == country ? true : nil
		} ?? false
	}
}
