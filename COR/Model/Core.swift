/// Persistent root state. HQ owns the player's roster and treasury between
/// scenarios; Tactical owns the running battle.
public struct Core: ~Copyable {
	public internal(set) var hq: HQSim
	public internal(set) var tactical: TacticalSim?

	public init(
		hq: consuming HQSim,
		tactical: consuming TacticalSim? = nil
	) {
		self.hq = hq
		self.tactical = tactical
	}
}

public extension Core {

	static func new(country: Country) -> Core {
		Core(
			hq: HQSim(
				player: Player(country: country, type: .human),
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
		tactical = nil
	}

	mutating func store(_ sim: borrowing TacticalSim) {
		tactical = clone(sim)
	}

	mutating func startScenario(_ sim: borrowing TacticalSim) {
		store(sim)
	}

	mutating func complete(_ sim: borrowing TacticalSim) {
		let country = hq.player.country
		hq.player.prestige = sim[country].prestige
		hq.units = sim.survivingRoster(for: country)
		tactical = nil
	}
}
