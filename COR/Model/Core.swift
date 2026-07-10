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
		hq = clone(sim)
		location = .hq
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
		tactical = clone(sim)
		location = .tactical
	}

	/// Pays the prestige cost of one fortification level from the campaign
	/// treasury; charges nothing and returns `false` when unaffordable.
	mutating func payForFort(_ cost: UInt16) -> Bool {
		guard hq.player.prestige >= cost else { return false }
		hq.player.prestige -= cost
		return true
	}

	mutating func startCampaignBattle(at tile: XY) {
		guard let defender = strategic?.owner[tile] else { return }

		let human = hq.player.country
		var prestige = hq.player.prestige
		prestige.increment(by: civilBonus(for: human))

		let players = [
			Player(country: human, type: .human, prestige: prestige),
			Player(country: defender, type: .ai, prestige: .poor + civilBonus(for: defender)),
		]
		let units = hq.units.compactMap { u in u.alive ? u : nil }
		let aux = [campaignAux(for: human), campaignAux(for: defender)]
		let buildingsMask = [
			strategic?.buildingsMask(of: human) ?? 0xFF,
			strategic?.buildingsMask(of: defender) ?? 0xFF,
			0xFF, 0xFF,
		] as [4 of UInt8]

		strategic?.battle = tile
		tactical = TacticalSim(
			players: players,
			units: units,
			size: 24,
			seed: tile.x + tile.y * 32,
			terrain: strategic?.terrain[tile] ?? .field,
			objective: .survive(defender.team, day: 20),
			forts: Int(strategic?.provinces[tile][.fort] ?? 0)//,
//			aux: aux,
//			buildingsMask: buildingsMask
		)
		location = .tactical
	}

	/// Recurring campaign income: every battle starts with +40 prestige per
	/// civil factory level the country owns.
	private func civilBonus(for country: Country) -> UInt16 {
		UInt16(40 * (strategic?.buildingsTotal(.civil, of: country) ?? 0))
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

	mutating func complete(_ sim: borrowing TacticalSim) {
		let c = hq.player.country
		let units: [Unit] = sim.units
			.compactMapAlive { i, u in
				u.country != c || u[.aux] ? nil : modifying(u) { u in
					u.reset()
				}
			}
		hq.units = [16 of Unit](head: Array(units.prefix(16)), tail: .empty)
		hq.player.prestige = sim[c].prestige

		tactical = nil

		if let tile = strategic?.battle {
			let won = sim.winner == c.team
			strategic?.resolveBattle(at: tile, won: won, by: c)
			location = .strategic
		} else {
			location = .hq
		}
	}

	mutating func goHQ() {
		guard location == .strategic else { return }
		location = .hq
	}
}
