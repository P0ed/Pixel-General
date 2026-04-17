extension TacticalState {

	mutating func runAI() {
		guard let target else { return action = .end }

		if let nextPurchase {
			action = nextPurchase
		} else if let nextReinforce {
			action = nextReinforce
		} else if let nextRetreat {
			action = nextRetreat
		} else if let nextAttack {
			action = nextAttack
		} else if let nextMove = nextMove(target: target) {
			action = nextMove
		} else {
			action = .end
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

	private var nextPurchase: TacticalAction? {
		player.prestige < 0x200 ? .none : buildings.firstMap { [country] _, b in
			b.country == country && unitsMap[b.position] < 0
			? shopUnits(at: b.position).enumerated().randomElement()
				.flatMap { i, t in t.cost * 2 <= player.prestige ? .purchase(i, b.position) : nil }
			: nil
		}
	}

	private func needsReinforcements(_ idx: Int, _ unit: Unit) -> Bool {
		(cargo[idx] == -1 || unit[.transport]) && (
			unit.hp < 6 || (
				!unit[.supply] && unit.ammo < unit.maxAmmo / 2
			)
		)
	}

	private var nextReinforce: TacticalAction? {
		units.firstMap { [country] i, u in
			(
				u.country == country && needsReinforcements(i, u)
				&& u.untouched && (!u.isAir || hasAirfield(position[i]))
			)
			? .resuply(i.uid)
			: nil
		}
	}

	private func hasAirfield(_ xy: XY) -> Bool {
		xy.n4.firstMap { xy in map[xy] == .airfield ? xy : nil } != nil
	}

	private var nextRetreat: TacticalAction? {
		units.firstMap { [country] i, u in
			(
				u.country == country && needsReinforcements(i, u)
			)
			? buildings.compactMap {
				$1.country == country && ($1.type == .airfield) == u.isAir ? $1 : nil
			}.min { a, b in
				a.position.distance(to: position[i]) < b.position.distance(to: position[i])
			}.flatMap { b in
				move(id: i.uid, to: b.position)
			}
			: nil
		}
	}

	private var nextAttack: TacticalAction? {
		units.firstMap { [country] i, u in
			u.country != country
			? nil
			: targets(uid: i.uid)
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
				.map { t in .attack(i.uid, t.0) }
		}
	}

	private func nextMove(target: XY) -> TacticalAction? {
		units.firstMap { [country] i, u in
			u.country != country ? nil : move(id: i.uid, to: target)
		}
	}

	private func move(id: UID, to target: XY) -> TacticalAction? {
		moves(for: id)
			.set
			.max(by: { a, b in
				(
					max(0, map[a].def) - target.distance(to: a)
				) < (
					max(0, map[b].def) - target.distance(to: b)
				)
			})
			.map { x in .move(id, x) }
	}
}
