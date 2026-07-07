extension TacticalSim {

	public func shopUnits(at xy: XY) -> [Unit] {
		let country = country
		guard map[xy].isSettlement, control[xy] == country else { return [] }

		let enemyAdjacent = neighbors(at: xy).contains { id in
			units[id].country.team != country.team
		}
		if enemyAdjacent { return [] }

		let unitSlots = units.reduceAlive(into: [0, 0] as [2 of Int]) { c, i, u in
			if u.country == country { c[u[.aux] ? 1 : 0] += 1 }
		}

		let core = unitSlots[0] < 16
		let aux = unitSlots[1] < 16

		let isAir = map[xy] == .airfield
		return .make { units in
			if core {
				units += Shop(country: country, tier: player.tier, air: isAir).units
			}
			if aux {
				units += auxilia[playerIndex]
					.compactMap { i, u in u.isAir == isAir ? u : nil }
			}
		}
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
		if unit[.aux] {
			let idx = auxilia[playerIndex].firstMap { i, u in u == template ? i : nil }
			if let idx { auxilia[playerIndex].remove(at: idx) }
		}
		events.append(.spawn(id))
	}
}
