public extension StrategicSim {

	/// Complete battle recipe for an offensive against `tile` by `army`,
	/// shared by the interactive Tactical launch and strategic autoresolve so
	/// both fight the identical battle. Seat 0 is the attacker, seat 1 the
	/// defender; the campaign player's country fights with its campaign
	/// treasury and progression, any other country fields a standard AI seat.
	func battleScenario(at tile: XY, by army: ArmyID) -> Scenario {
		let defender = owner[tile]
		let units = roster(army.index, for: army.country).compactMap { u in u.alive ? u : nil }
			+ defendingCore(for: defender, near: tile)
			+ campaignAux(for: army.country)
			+ campaignAux(for: defender)
		return Scenario(
			players: [battlePlayer(for: army.country), battlePlayer(for: defender)],
			units: units,
			terrain: battleTerrain(at: tile, attackingFrom: self.army(army).position),
			// The attacker holds terrain index 3 (west-middle), the defender
			// index 4 — the defended center province.
			spawns: [XY(0, 1), XY(1, 1), nil, nil],
			fortLevel: fortLevel(at: tile),
			seed: tile.x + tile.y * 32,
			objective: .survive(defender.team, day: 24),
			buildingsMask: [
				buildingsMask(of: army.country),
				buildingsMask(of: defender),
				0xFF, 0xFF,
			]
		)
	}
}

private extension StrategicSim {

	func battlePlayer(for country: Country) -> Player {
		var seat = country == player.country
			? player
			: Player(country: country, type: .ai, prestige: .poor)
		seat.prestige.increment(by: civilBonus(for: country))
		return seat
	}

	/// Recurring campaign income: every battle starts with +40 prestige per
	/// civil factory level the country owns.
	func civilBonus(for country: Country) -> UInt16 {
		UInt16(40 * buildingsTotal(.civil, of: country))
	}

	/// The auxiliary force a country fields in a campaign battle, sized by its
	/// country-wide military factory totals.
	func campaignAux(for country: Country) -> [Unit] {
		.aux(
			country,
			army: buildingsTotal(.army, of: country),
			armor: buildingsTotal(.armor, of: country),
			air: buildingsTotal(.air, of: country),
			aa: buildingsTotal(.aa, of: country)
		)
	}
}
