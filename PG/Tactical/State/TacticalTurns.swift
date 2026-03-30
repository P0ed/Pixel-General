extension TacticalState {

	var day: Int { Int(turn) / players.count + 1 }

	private var aliveTeams: Set<Team> {
		Set(players.map { _, p in p.country.team })
	}

	mutating func endTurn() {
		captureCities()

		guard nextTurn() else { return _ = events.add(.gameOver) }

		resetUI()
	}

	private mutating func nextTurn() -> Bool {
		for _ in 0..<players.count {
			turn += 1
			if playerIndex == 0 { startNextDay() }
			if player.alive {
				return players.firstMap { _, p in !p.ai ? () : nil } != nil
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
			endTurn(unit: i)
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

		cursor = units.firstMap { [country] _, u in
			u.country == country ? u.position : nil
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
		var unit = units[id]
		let neighbors = neighbors(at: unit.position)

		let noEnemy = !neighbors.contains { n in
			units[n].country.team != unit.country.team
		}
		let hasSupply = neighbors.contains { n in
			units[n].country.team == unit.country.team
			&& units[n][.supply]
		}
		let hasBuildings = buildings.firstMap { _, b in
			b.country == unit.country
			&& (b.type == .airfield) == unit.isAir
			&& b.position.distance(to: unit.position) <= 2
			? b : nil
		} != nil
		if !unit.isAir {
			unit.ent.increment(
				by: (unit.untouched ? 1 : 0) + (hasSupply ? 1 : 0),
				cap: 7
			)
		}
		if unit.maxAmmo > 0, !unit.isAir || hasBuildings {
			unit.ammo.increment(
				by: (unit.untouched ? (noEnemy ? 2 : 1) : 0) + (hasSupply ? (noEnemy ? 2 : 0) : 0),
				cap: unit.maxAmmo
			)
		}
		if !unit.isAir || hasBuildings {
			unit.healLoosingXP(
				(unit.untouched ? (noEnemy ? 4 : 2) : 0) + (hasSupply ? (noEnemy ? 3 : 1) : 0)
			)
		}
		unit.ap = 0b11
		units[id] = unit
	}

	func neighbors(at position: XY) -> [UID] {
		position.n8.compactMap { xy in units[xy]?.0 }
	}

	private mutating func captureCities() {
		let reflag = units.reduce(into: false) { reflag, _, u in

			let idx = buildings.firstMap { i, b in
				b.position == u.position ? i : nil
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
