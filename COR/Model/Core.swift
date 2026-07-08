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

	mutating func startCampaignBattle(at tile: XY) {
		guard let defender = strategic?.owner[tile] else { return }

		let human = hq.player.country
		let prestige = hq.player.prestige

		let players = [
			Player(country: human, type: .human, prestige: prestige),
			Player(country: defender, type: .ai),
		]
		let units = hq.units.compactMap { u in u.alive ? u : nil }

		strategic?.battle = tile
		tactical = TacticalSim(
			players: players,
			units: units,
			size: 24,
			seed: tile.x + tile.y * 32,
			terrain: strategic?.terrain[tile] ?? .field,
			objective: .survive(defender.team, day: 20)
		)
		location = .tactical
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
