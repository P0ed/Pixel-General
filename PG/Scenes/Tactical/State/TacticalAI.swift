extension TacticalState {

	mutating func runAI() {
		let target = buildings.firstMap { [country] _, b in
			b.country.team != country.team ? b.position : nil
		}
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
				.min(by: { ha, hb in
					target.distance(to: ha) < target.distance(to: hb)
				})
				.map { hx in (i, hx) }
			: nil
		}
	}
}
