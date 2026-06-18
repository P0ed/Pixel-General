public struct Core: ~Copyable {
	public internal(set) var hq: HQState?
	public internal(set) var strategic: StrategicState?
	public internal(set) var tactical: TacticalState?
	public internal(set) var location: Location = .hq

	public init(
		hq: consuming HQState? = nil,
		strategic: consuming StrategicState? = nil,
		tactical: consuming TacticalState? = nil,
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
			hq: HQState(
				sim: HQSim(
					player: Player(country: country, type: .human),
					units: .init(
						head: modifying(.base(country)) { base in
							base.modifyEach { u in u.reset() }
						},
						tail: .empty
					)
				)
			)
		)
	}

	mutating func store(_ state: borrowing HQState) {
		hq = clone(state)
		location = .hq
	}

	mutating func store(_ state: borrowing TacticalState) {
		guard hq != nil else { return }
		tactical = clone(state)
		location = .tactical
	}

	mutating func store(_ state: borrowing StrategicState) {
		guard hq != nil else { return }
		strategic = clone(state)
		location = .strategic
	}

	mutating func startScenario(_ state: borrowing TacticalState) {
		tactical = clone(state)
		location = .tactical
	}

	mutating func startCampaignBattle(at tile: XY) {
		guard let human = hq?.sim.player.country,
			let prestige = hq?.sim.player.prestige,
			let defender = strategic?.sim.owner[tile]
		else { return }

		let players = [
			Player(country: human, type: .human, prestige: prestige),
			Player(country: defender, type: .ai),
		]
		let units = hq?.sim.units.compactMap { u in u.alive ? u : nil } ?? []

		strategic?.sim.battle = tile
		tactical = TacticalState(
			players: players,
			objective: .survive(defender.team, day: 20),
			units: units,
			size: 24,
			seed: tile.x + tile.y * 32
		)
		location = .tactical
	}

	mutating func startCampaign(_ hq: borrowing HQState, _ strategic: borrowing StrategicState) {
		self.hq = clone(hq)
		self.strategic = clone(strategic)
		location = .strategic
	}

	mutating func complete(_ state: borrowing TacticalState) {
		guard let c = hq?.sim.player.country else {
			tactical = nil
			location = .hq
			return
		}

		let units: [Unit] = state.sim.units
			.compactMapAlive { i, u in
				u.country != c || u[.aux] ? nil : modifying(u) { u in
					u.reset()
				}
			}
		hq?.sim.units = [16 of Unit](head: Array(units.prefix(16)), tail: .empty)
		hq?.sim.player.prestige = state.sim[c].prestige

		tactical = nil

		if let tile = strategic?.sim.battle {
			let won = state.sim.winner == c.team
			strategic?.sim.resolveBattle(at: tile, won: won, by: c)
			location = .strategic
		} else {
			hq?.ui.cursor = .zero
			location = .hq
		}
	}

	mutating func goHQ() {
		guard location == .strategic else { return }
		location = .hq
	}
}
