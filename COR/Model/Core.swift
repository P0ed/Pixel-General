/// Persistent root state. Without a campaign, `hq` owns the player's roster
/// and treasury. With a campaign, `strategic` owns them; `hq` is then only the
/// selected army's editor snapshot while `location == .hq`.
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

	/// Stores the active HQ editor. Campaign editors write their player and
	/// roster through to the selected strategic army; standalone HQ state has
	/// no second owner.
	mutating func store(_ sim: borrowing HQSim) {
		if strategic != nil {
			strategic?.player = sim.player
			strategic?.setRoster(sim.units, slot: sim.army)
		}
		hq = clone(sim)
		location = .hq
	}

	/// Opens an army's roster in the HQ screen.
	mutating func openArmy(_ slot: Int) {
		guard location == .strategic,
			  (0 ..< 4).contains(slot),
			  strategic?.armyIsActive(slot) == true
		else { return }
		hq = HQSim(
			player: strategic!.player,
			units: strategic!.roster(slot),
			army: slot
		)
		location = .hq
	}

	/// Returns from an army roster to the strategic map.
	mutating func closeArmy() {
		guard location == .hq, strategic != nil else { return }
		location = .strategic
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

	mutating func startCampaignBattle(at tile: XY, by requestedSlot: Int? = nil) {
		guard location == .strategic,
			  let slot = requestedSlot ?? strategic?.attackingArmy(at: tile),
			  strategic?.canAttack(tile, with: ArmyID(country: strategic!.player.country, slot: slot)) == true
		else { return }

		let scenario = strategic!.battleScenario(
			at: tile,
			by: ArmyID(country: strategic!.player.country, slot: slot)
		)
		strategic?.launchBattle(at: tile, by: slot)
		tactical = scenario.makeSim()
		location = .tactical
	}

	/// Resolves the selected human offensive entirely on the campaign map by
	/// simulating its battle headlessly.
	@discardableResult
	mutating func autoResolveCampaignBattle(at tile: XY, by slot: Int) -> Bool? {
		guard location == .strategic, strategic != nil else { return nil }
		let country = strategic!.player.country
		return strategic?.autoResolveAttack(at: tile, by: ArmyID(country: country, slot: slot))
	}

	mutating func startCampaign(_ hq: borrowing HQSim, _ strategic: borrowing StrategicSim) {
		self.hq = clone(hq)
		self.strategic = clone(strategic)
		self.strategic?.player = hq.player
		self.strategic?.setRoster(hq.units, slot: 0)
		location = .strategic
	}

	mutating func complete(_ sim: borrowing TacticalSim) {
		let c = strategic?.player.country ?? hq.player.country
		let roster = sim.survivingRoster(for: c)
		let battleTile = strategic?.battle
		let defender = battleTile.map { strategic?.owner(at: $0) ?? .none } ?? .none
		let defendingArmy = battleTile.flatMap { strategic?.defendingArmy(for: defender, near: $0) }
		tactical = nil

		if strategic != nil {
			strategic?.player.prestige = sim[c].prestige
			// Survivors return to the army that fought; a wiped side army
			// disbands. Read the slot before `resolveBattle` clears it.
			let slot = strategic?.fightingSlot() ?? 0
			strategic?.setRoster(roster, slot: slot)
			strategic?.disbandIfWipedOut(slot)
			if let defendingArmy {
				let defenders = sim.survivingRoster(for: defendingArmy.country)
				strategic?.setRoster(
					defenders,
					slot: defendingArmy.index,
					for: defendingArmy.country
				)
				strategic?.disbandIfWipedOut(defendingArmy.index, for: defendingArmy.country)
			}
			if let tile = strategic?.battle {
				let won = sim.winner == c.team
				strategic?.resolveBattle(at: tile, won: won, by: c)
			}
			location = .strategic
		} else {
			hq.player.prestige = sim[c].prestige
			hq.units = roster
			location = .hq
		}
	}

}
