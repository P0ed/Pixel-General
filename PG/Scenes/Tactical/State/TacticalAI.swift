extension TacticalState {

	mutating func runAI() {
		guard let target else { return }

		if let nextPurchase {
			buy(nextPurchase.0, at: nextPurchase.1)
		} else if let nextAttack {
			attack(src: nextAttack.0, dst: nextAttack.1)
		} else if let nextMove = nextMove(target: target) {
			move(unit: nextMove.0, to: nextMove.1)
		} else {
			endTurn()
		}
	}

	private var target: XY? {
		let ownCities = buildings.compactMap { [country] _, b in
			b.country == country ? b : nil
		}
		let cnt = XY(ownCities.count, ownCities.count)
		let mid = ownCities.reduce(.zero as XY) { r, e in r + e.position / cnt }
		return buildings.compactMap { [country] _, b in
			b.country.team != country.team ? b.position : nil
		}
		.sorted { a, b in a.distance(to: mid) < b.distance(to: mid) }
		.first
	}

	private var nextPurchase: (Unit, XY)? {
		player.prestige < 400 ? .none : buildings.firstMap { [country] _, b in
			b.country == country && b.type == .city && units[b.position] == nil
			? unitTemplates.randomElement()
				.flatMap { t in t.cost <= player.prestige ? (t, b.position) : nil }
			: nil
		}
	}

	private var nextAttack: (UID, UID)? {
		units.firstMap { [country] i, u in
			u.country == country
			? targets(unit: u).firstMap { t in (i, t.0) }
			: nil
		}
	}

	private func nextMove(target: XY) -> (UID, XY)? {
		units.firstMap { [country] i, u in
			u.country == country
			? moves(for: u)
				.set
				.min(by: { a, b in
					target.distance(to: a) < target.distance(to: b)
				})
				.map { x in (i, x) }
			: nil
		}
	}
}
