extension TacticalSim {

	func soviet(ai: inout AI) -> TacticalAction {
		guard let target else { return .end }

		if let nextPurchase { return nextPurchase }
		if let nextReinforce { return nextReinforce }
		if let nextRetreat { return nextRetreat}
		if let nextAttack { return nextAttack }
		if let nextMove = nextMove(target: target) { return nextMove }

		return .end
	}

	private var target: XY? {
		let ownCities: [XY] = map.indices.compactMap { [country] xy in
			map[xy].isSettlement && control[xy] == country ? xy : nil
		}
		let cnt = XY(ownCities.count, ownCities.count)
		let mid = ownCities.reduce(.zero as XY) { r, e in r + e / cnt }
		return map.indices.compactMap { [country] xy in
			map[xy].isSettlement && control[xy].team != country.team ? xy : nil
		}
		.sorted { a, b in a.stepDistance(to: mid) < b.stepDistance(to: mid) }
		.first
	}

	private var nextPurchase: TacticalAction? {
		guard player.prestige >= 0x200 else { return nil }
		for xy in map.indices {
			guard map[xy].isSettlement, control[xy] == country, unitsMap[xy] == .none else { continue }
			var d20 = D20(seed: d20.seed ^ UInt64(xy.x) ^ UInt64(xy.y) << 8)
			if let (i, t) = shopUnits(at: xy).enumerated().randomElement(using: &d20),
			   t.cost * 2 <= player.prestige {
				return .purchase(i, xy)
			}
		}
		return nil
	}

	private func needsReinforcements(_ idx: Int, _ unit: Unit) -> Bool {
		(cargo[idx] == .none || unit[.transport]) && (
			unit.hp < 6 || (
				unit.type != .supply && unit.ammo < unit.maxAmmo / 2
			)
		)
	}

	private var nextReinforce: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			(
				u.country == country && needsReinforcements(i, u)
				&& u.untouched && (!u.isAir || hasAirfield(position[i]))
			)
			? .resupply(i.uid)
			: nil
		}
	}

	private func hasAirfield(_ xy: XY) -> Bool {
		xy.n4.firstMap { xy in map[xy] == .airfield ? xy : nil } != nil
	}

	private var nextRetreat: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			guard u.country == country, needsReinforcements(i, u) else { return nil }
			let havens: [XY] = map.indices.compactMap { xy in
				map[xy].isSettlement && control[xy] == country
				&& (map[xy] == .airfield) == u.isAir ? xy : nil
			}
			return havens.min { a, b in
				a.stepDistance(to: position[i]) < b.stepDistance(to: position[i])
			}.flatMap { xy in
				move(id: i.uid, to: xy)
			}
		}
	}

	private var nextAttack: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			u.country != country
			? nil
			: targets(id: i.uid)
				.max(by: { a, b in
					(
						(a.1.isArt ? 5 : 0)
						+ (a.1.isAA ? 6 : 0)
						+ (a.1.maxHP - a.1.hp)
						+ (u.isAA && a.1.isAir ? 10 : 0)
					) < (
						(b.1.isArt ? 5 : 0)
						+ (b.1.isAA ? 6 : 0)
						+ (b.1.maxHP - b.1.hp)
						+ (u.isAA && b.1.isAir ? 10 : 0)
					)
				})
				.map { t in .attack(i.uid, t.0) }
		}
	}

	private func nextMove(target: XY) -> TacticalAction? {
		units.firstMapAlive { [country] i, u in
			u.country != country ? nil : move(id: i.uid, to: target)
		}
	}

	private func move(id: UID, to target: XY) -> TacticalAction? {
		moves(for: id)
			.ordered
			.max(by: { a, b in
				(
					max(0, Int(map[a].baseEntrenchment)) - target.stepDistance(to: a)
				) < (
					max(0, Int(map[b].baseEntrenchment)) - target.stepDistance(to: b)
				)
			})
			.map { x in .move(id, x) }
	}

	private func targets(id: UID) -> [(UID, Unit)] {
		let su = units[id]
		return !su.canAttack ? [] : units.reduceAlive(into: []) { r, i, du in
			if du.country.team != su.country.team, isVisible(i.uid), unitCanHit(id, i.uid) {
				r.append((i.uid, du))
			}
		}
	}
}
