public struct Core: ~Copyable {
	public internal(set) var hq: HQSim
	public internal(set) var strategic: StrategicSim?
	public internal(set) var tactical: TacticalSim?
	public internal(set) var location: Location = .hq

	public init(
		hq: consuming HQSim,
		strategic: consuming StrategicSim? = nil,
		tactical: consuming TacticalSim? = nil,
		location: Location = .hq
	) {
		self.hq = hq
		self.strategic = strategic
		self.tactical = tactical
		self.location = location
	}
}

@frozen public enum Location: UInt8 {
	case hq, strategic, tactical
}

public extension Core {

	static func new(country: Country) -> Core {
		Core(
			hq: HQSim(
				player: Player(country: country, type: .human, tier: 3),
				units: .init(
					head: modifying(.base(country)) { base in
						base.modifyEach { u in u.reset() }
					},
					tail: .empty
				)
			)
		)
	}

	mutating func store(_ sim: borrowing HQSim) {
		if strategic != nil {
			strategic?.player.prestige = sim.player.prestige
			strategic?.setRoster(sim.units, slot: sim.army)
		} else {
			hq = clone(sim)
		}
		location = .hq
	}

	/// Opens an army's roster in the HQ screen.
	mutating func openArmy(_ slot: Int) {
		guard location == .strategic else { return }
		hq.army = slot
		hq.units = strategic!.roster(slot)
		location = .hq
	}

	/// Returns from an army roster to the strategic map.
	mutating func closeArmy() {
		guard location == .hq else { return }
		location = .strategic
	}

	/// Charges end-of-turn army upkeep, clamping at an empty treasury.
	mutating func payUpkeep(_ cost: UInt16) {
		// TODO: Move to StrategicSim.reduce
		hq.player.prestige.decrement(by: cost)
	}

	mutating func store(_ sim: borrowing TacticalSim) {
		tactical = clone(sim)
		location = .tactical
	}

	mutating func store(_ sim: borrowing StrategicSim) {
		strategic = clone(sim)
		location = .strategic
	}

	mutating func startScenario(_ sim: borrowing TacticalSim) {
		store(sim)
	}

	mutating func startCampaignBattle(at tile: XY) {
		guard let defender = strategic?.owner(at: tile),
			  let slot = strategic?.attackingArmy(at: tile)
		else { return }

		let human = hq.player.country
		var prestige = hq.player.prestige
		prestige.increment(by: civilBonus(for: human))

		let players = [
			Player(country: human, type: .human, prestige: prestige),
			Player(country: defender, type: .ai, prestige: .poor + civilBonus(for: defender)),
		]
		let units = armyRoster(slot)
			+ (strategic?.reinforcement(for: defender, near: tile) ?? [])
			+ campaignAux(for: human)
			+ campaignAux(for: defender)
		strategic?.launchBattle(at: tile, by: slot)

		let buildingsMask = [
			strategic?.buildingsMask(of: human) ?? 0xFF,
			strategic?.buildingsMask(of: defender) ?? 0xFF,
			0xFF, 0xFF,
		] as [4 of UInt8]

		tactical = TacticalSim(
			players: players,
			units: units,
			size: 24,
			seed: tile.x + tile.y * 32,
			terrain: strategic?.terrain(at: tile) ?? .field,
			objective: .survive(defender.team, day: 20),
			forts: strategic?.fortLevel(at: tile) ?? 0,
			buildingsMask: buildingsMask
		)
		location = .tactical
	}

	/// Recurring campaign income: every battle starts with +40 prestige per
	/// civil factory level the country owns.
	private func civilBonus(for country: Country) -> UInt16 {
		UInt16(40 * (strategic?.buildingsTotal(.civil, of: country) ?? 0))
	}

	/// The alive core force an army slot fields — the HQ roster for the
	/// main army, the campaign roster otherwise.
	private func armyRoster(_ slot: Int) -> [Unit] {
		if slot > 0, let units = strategic?.roster(slot) {
			return units.compactMap { u in u.alive ? u : nil }
		}
		return hq.units.compactMap { u in u.alive ? u : nil }
	}

	/// The auxilia a country fields in a campaign battle, sized by its
	/// country-wide military factory totals.
	private func campaignAux(for country: Country) -> [Unit] {
		.aux(
			country,
			army: strategic?.buildingsTotal(.army, of: country) ?? 0,
			armor: strategic?.buildingsTotal(.armor, of: country) ?? 0,
			air: strategic?.buildingsTotal(.air, of: country) ?? 0,
			aa: strategic?.buildingsTotal(.aa, of: country) ?? 0
		)
	}

	mutating func startCampaign(_ hq: borrowing HQSim, _ strategic: borrowing StrategicSim) {
		self.hq = clone(hq)
		self.strategic = clone(strategic)
		location = .strategic
	}

	mutating func continueCampaign(_ hq: borrowing HQSim) {
		guard strategic != nil else { return }
		self.hq = clone(hq)
		location = .strategic
	}

	mutating func complete(_ sim: borrowing TacticalSim) {
		let c = hq.player.country
		let units: [Unit] = sim.units
			.compactMapAlive { i, u in
				u.country != c || u[.aux] ? nil : modifying(u) { u in
					u.reset()
				}
			}
		let roster = [16 of Unit](head: Array(units.prefix(16)), tail: .empty)
		hq.player.prestige = sim[c].prestige

		tactical = nil

		if let tile = strategic?.battle {
			// Survivors return to the army that fought; a wiped side army
			// disbands. Read the slot before `resolveBattle` clears it.
			let slot = strategic?.fightingSlot() ?? 0
			if slot > 0 {
				strategic?.setRoster(roster, slot: slot)
				strategic?.disbandIfWipedOut(slot)
			} else {
				hq.units = roster
			}
			let won = sim.winner == c.team
			strategic?.resolveBattle(at: tile, won: won, by: c)
			location = .strategic
		} else {
			hq.units = roster
			location = .hq
		}
	}

	mutating func goHQ() {
		// TODO: You only go to the HQ with an army.
		// `Core.hq` makes no sense on it's own when Core.strategic is non-nil
		guard location == .strategic else { return }
		location = .hq
	}
}
