/// Persistent root state. HQ owns the player's roster and treasury between
/// scenarios; Tactical owns the running battle.
public struct Core: ~Copyable {
	public internal(set) var hq: HQSim
	public internal(set) var tactical: TacticalSim?
	public internal(set) var location: Location = .hq

	public init(
		hq: consuming HQSim,
		tactical: consuming TacticalSim? = nil,
		location: Location = .hq
	) {
		self.hq = hq
		self.tactical = tactical
		self.location = location
	}
}

@frozen public enum Location: UInt8 {
	case hq, tactical
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
		location = .hq
	}

	mutating func store(_ sim: borrowing TacticalSim) {
		tactical = clone(sim)
		location = .tactical
	}

	mutating func startScenario(_ sim: borrowing TacticalSim) {
		store(sim)
	}

	mutating func complete(_ sim: borrowing TacticalSim) {
		let country = hq.player.country
		hq.player.prestige = sim[country].prestige
		hq.units = sim.survivingRoster(for: country)
		tactical = nil
		location = .hq
	}
}
