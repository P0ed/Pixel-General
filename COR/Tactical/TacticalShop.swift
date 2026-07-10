extension TacticalSim {

	public func shopUnits(at xy: XY) -> [Unit] {
		let country = country
		guard map[xy].isSettlement, control[xy] == country else { return [] }

		let enemyAdjacent = neighbors(at: xy).contains { id in
			units[id].country.team != country.team
		}
		if enemyAdjacent { return [] }

		let coreSlots = units.reduceAlive(into: 0) { c, i, u in
			if u.country == country, !u[.aux] { c += 1 }
		}
		guard coreSlots < 16 else { return [] }

		return Shop(
			country: country,
			tier: player.tier,
			air: map[xy] == .airfield,
			factories: buildingsMask[playerIndex]
		).units
	}

	/// Mirror of the `.purchase` reducer guard for one shop slot — shared by
	/// `buy` and `slotMask`. `shopUnits` itself owns the tile half of the rule
	/// (settlement, ownership, enemy contact, roster slots).
	func canBuy(slot idx: Int, at pos: XY) -> Bool {
		guard unitsMap[pos] == .none else { return false }
		let shop = shopUnits(at: pos)
		return idx >= 0 && idx < shop.count && player.prestige >= shop[idx].cost
	}

	/// `canBuy(slot:at:)` for any slot — the purchase actor mask.
	func canBuy(at xy: XY) -> Bool {
		unitsMap[xy] == .none
		&& shopUnits(at: xy).contains { u in player.prestige >= u.cost }
	}

	mutating func buy(_ idx: Int, at pos: XY, into events: inout [TacticalEvent]) {
		guard canBuy(slot: idx, at: pos) else { return }
		let template = shopUnits(at: pos)[idx]

		let unit = modifying(template) { u in
			u.reset()
			u.mp = 0
			u.ap = 0
			u.lvl += player.baseLevel
		}
		let id = spawn(unit, at: pos)
		player.prestige.decrement(by: unit.cost)
		events.append(.spawn(id))
	}
}
