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
		?? buildings.firstMap { _, b in
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
			&& units[n].stats[.supply]
		}
		unit.stats.ent.increment(
			by: unit.stats.isAir ? 0 : (unit.untouched ? 1 : 0) + (hasSupply ? 1 : 0),
			cap: 7
		)
		unit.stats.ammo.increment(
			by: unit.stats[.supply]
			? 0 : (
				(unit.untouched ? 2 : 0) + (noEnemy ? 2 : 0) + (hasSupply ? 2 : 0)
			),
			cap: 0x7
		)
		let dhp = unit.stats.hp.increment(
			by: ((unit.untouched ? 4 : 0) + (hasSupply ? 4 : 0)) / (noEnemy ? 1 : 3),
			cap: 0xF
		)
		unit.stats.exp.decrement(by: dhp * 1 << unit.stats.stars)

		unit.stats.mp = 1
		unit.stats.ap = 1
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

			if let idx, buildings[idx].country.team != u.country.team {
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
