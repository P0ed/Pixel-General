public struct Core: ~Copyable {
	public internal(set) var hq: HQState
	public internal(set) var tactical: TACState

	public init(
		hq: consuming HQState,
		tactical: consuming TACState
	) {
		self.hq = hq
		self.tactical = tactical
	}
}

public extension Core {

	static func new(country: Country) -> Core {
		Core(
			hq: HQState(
				player: Player(country: country, type: .human),
				units: .init(
					head: modifying(.base(country)) { base in
						base.modifyEach { u in u.reset() }
					},
					tail: .empty
				)
			),
			tactical: .empty
		)
	}

	mutating func store(_ state: borrowing HQState) {
		hq = clone(state)
	}

	mutating func store(_ state: borrowing TACState) {
		tactical = clone(state)
	}

	mutating func complete(_ sim: borrowing TACState) {
		let country = hq.player.country
		hq.player.prestige.increment(by: sim.winner == hq.player.country.team ? 600 : 0)
		hq.units = sim.survivingRoster(for: country)
		tactical.isFinished = true
	}
}
