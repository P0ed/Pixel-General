extension TacticalSim {

	static let coreUnitLimit = 16
	static let totalUnitLimit = 48

	public func shopUnits(at xy: XY, aux: Bool = false) -> [Unit] {
		guard aux || map[xy] != .port else { return [] }
		let country = country
		let counts = units.reduceAlive(into: (core: 0, total: 0)) { counts, _, unit in
			guard unit.country == country else { return }
			counts.total += 1
			if !unit[.aux] { counts.core += 1 }
		}
		guard counts.total < Self.totalUnitLimit, aux || counts.core < Self.coreUnitLimit else { return [] }

		let offers = purchaseCatalog(at: xy)
		return aux ? offers.map(\.aux) : offers
	}

	func purchaseCatalog(at xy: XY) -> [Unit] {
		let country = country
		guard map[xy].isSettlement, control[xy] == country else { return [] }

		let enemyAdjacent = neighbors(at: xy).contains { id in
			units[id].country.team != country.team && units[id].isLand
		}
		if enemyAdjacent { return [] }

		if map[xy] == .port { return Shop(country: country, tier: player.tier).navalUnits }
		return Shop(
			country: country,
			tier: player.tier,
			air: map[xy] == .airfield
		).units
	}

	func canBuy(slot idx: Int, at pos: XY, aux: Bool = false) -> Bool {
		purchasableUnit(slot: idx, at: pos, aux: aux) != nil
	}

	func canBuy(at xy: XY) -> Bool {
		unitsMap[xy] == .none
		&& shopUnits(at: xy, aux: true).contains { u in player.prestige >= u.stats.cost }
	}

	private func purchasableUnit(slot idx: Int, at pos: XY, aux: Bool) -> Unit? {
		guard unitsMap[pos] == .none else { return nil }
		let shop = shopUnits(at: pos, aux: aux)
		guard shop.indices.contains(idx), player.prestige >= shop[idx].stats.cost else { return nil }
		return shop[idx]
	}

	mutating func buy(_ idx: Int, at pos: XY, aux: Bool, into events: inout [Event]) {
		guard let template = purchasableUnit(slot: idx, at: pos, aux: aux) else { return }
		let unit = modifying(template) { u in
			u.reset()
			u.mp = 0
			u.ap = 0
			u.lvl += player.baseLevel
		}
		let id = spawn(unit, at: pos)
		player.prestige.decrement(by: unit.stats.cost)
		events.append(.spawn(id))
	}
}
