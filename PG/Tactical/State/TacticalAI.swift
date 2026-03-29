extension TacticalState {

	mutating func runAI() {
		guard let target else { return endTurn() }

		if let nextPurchase {
			buy(nextPurchase.0, at: nextPurchase.1)
		} else if let nextRetreat {
			move(unit: nextRetreat.0, to: nextRetreat.1)
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
		player.prestige < 0x200 ? .none : buildings.firstMap { [country] _, b in
			b.country == country && unitsMap[b.position] < 0
			? shopUnits(at: b.position).randomElement()
				.flatMap { t in t.cost * 2 <= player.prestige ? (t, b.position) : nil }
			: nil
		}
	}

	private var nextRetreat: (UID, XY)? {
		units.firstMap { [country] i, u in
			u.country != country || (u.hp > 5 && (u.ammo >= u.maxAmmo / 2 || u[.supply]))
			? nil
			: buildings.compactMap {
				$1.country == country && ($1.type == .airfield) == u.isAir ? $1 : nil
			}.min { a, b in
				a.position.distance(to: u.position) < b.position.distance(to: u.position)
			}.flatMap { b in
				move(id: i, to: b.position)
			}
		}
	}

	private var nextAttack: (UID, UID)? {
		units.firstMap { [country] i, u in
			u.country != country
			? nil
			: targets(unit: u)
				.max(by: { a, b in
					(
						(a.1[.art] ? 5 : 0)
						+ (a.1[.aa] ? 6 : 0)
						+ (0xF - a.1.hp)
						+ (u[.aa] && a.1.isAir ? 10 : 0)
					) < (
						(b.1[.art] ? 5 : 0)
						+ (b.1[.aa] ? 6 : 0)
						+ (0xF - b.1.hp)
						+ (u[.aa] && b.1.isAir ? 10 : 0)
					)
				})
				.map { t in (i, t.0) }
		}
	}

	private func nextMove(target: XY) -> (UID, XY)? {
		units.firstMap { [country] i, u in
			u.country != country ? nil : move(id: i, to: target)
		}
	}

	private func move(id: UID, to target: XY) -> (UID, XY)? {
		moves(for: units[id])
			.set
			.max(by: { a, b in
				(
					max(0, map[a].def) - target.distance(to: a)
				) < (
					max(0, map[b].def) - target.distance(to: b)
				)
			})
			.map { x in (id, x) }
	}
}
