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
		let country = country
		var ownCount = 0
		settlements.forEach { xy in
			if control[xy] == country { ownCount += 1 }
		}
		var mid = XY.zero
		if ownCount > 0 {
			let cnt = XY(ownCount, ownCount)
			settlements.forEach { xy in
				if control[xy] == country { mid = mid + xy / cnt }
			}
		}
		var best: XY? = nil
		var bestD = Int.max
		settlements.forEach { xy in
			guard control[xy].team != country.team else { return }
			let d = xy.stepDistance(to: mid)
			if d < bestD { bestD = d; best = xy }
		}
		return best
	}

	private var nextPurchase: TacticalAction? {
		guard player.prestige >= 0x200 else { return nil }
		return settlements.firstMap { [country] xy in
			guard control[xy] == country, unitsMap[xy] == .none else { return nil }
			var d20 = D20(seed: d20.seed ^ UInt64(xy.x) ^ UInt64(xy.y) << 8)
			guard let (i, t) = shopUnits(at: xy).enumerated().randomElement(using: &d20),
				  t.cost * 2 <= player.prestige
			else { return nil }
			return .purchase(i, xy)
		}
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
			u.country == country && needsReinforcements(i, u) && canResupply(unit: i.uid)
			? .resupply(i.uid)
			: nil
		}
	}

	private var nextRetreat: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			guard u.country == country, needsReinforcements(i, u) else { return nil }
			var haven: XY? = nil
			var bestD = Int.max
			settlements.forEach { xy in
				guard control[xy] == country, (map[xy] == .airfield) == u.isAir else { return }
				let d = xy.stepDistance(to: position[i])
				if d < bestD { bestD = d; haven = xy }
			}
			return haven.flatMap { xy in
				move(id: i.uid, to: xy)
			}
		}
	}

	private var nextAttack: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			guard u.country == country else { return nil }
			var best: UID = .none
			var bestScore = Int.min
			units.forEachAlive { j, du in
				guard canAttack(src: i.uid, dst: j.uid) else { return }
				let score = (du.isArt ? 5 : 0)
					+ (du.isAA ? 6 : 0)
					+ Int(du.maxHP - du.hp)
					+ (u.isAA && du.isAir ? 10 : 0)
				if score > bestScore { bestScore = score; best = j.uid }
			}
			return best == .none ? nil : .attack(i.uid, best)
		}
	}

	private func nextMove(target: XY) -> TacticalAction? {
		units.firstMapAlive { [country] i, u in
			u.country != country ? nil : move(id: i.uid, to: target)
		}
	}

	private func move(id: UID, to target: XY) -> TacticalAction? {
		let mv = moves(for: id)
		var best: XY? = nil
		var bestScore = Int.min
		for xy in mv.moves.indices where mv.moves[xy] > 0 {
			let score = max(0, Int(map[xy].baseEntrenchment)) - target.stepDistance(to: xy)
			if score > bestScore { bestScore = score; best = xy }
		}
		return best.map { x in .move(id, x) }
	}
}
