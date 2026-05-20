extension TacticalState {

	func alliesAI(ai: inout AI) -> TacticalAction {
		if let act = purchase { return act }
		if let act = resupply { return act }
		if let act = disembark { return act }
		if let act = embark { return act }
		if let act = attack { return act }
		if let act = retreat { return act }
		if let act = move { return act }
		return .end
	}

	// MARK: - Objectives
	private var enemyCities: [XY] {
		buildings.compactMap { [country] _, b in
			b.country.team != country.team && b.type == .city ? b.position : nil
		}
	}

	private var ownCities: [Building] {
		buildings.compactMap { [country] _, b in
			b.country == country && b.type == .city ? b : nil
		}
	}

	private var ownAirfields: [Building] {
		buildings.compactMap { [country] _, b in
			b.country == country && b.type == .airfield ? b : nil
		}
	}

	private var threatenedCities: [XY] {
		ownCities.compactMap { [country] b in
			let nearby = units.firstMap { i, u in
				u.country.team != country.team && !u.isAir
				&& isVisible(i.uid)
				&& position[i].stepDistance(to: b.position) <= 4
				? true : nil
			} ?? false
			return nearby ? b.position : nil
		}
	}

	private var enemyHasAir: Bool {
		units.firstMap { [country] i, u in
			u.country.team != country.team && u.isAir && isVisible(i.uid) ? true : nil
		} ?? false
	}

	private func objective(for uid: UID) -> XY? {
		let u = units[uid.index]
		let p = position[uid.index]

		if u.isAir, u.ammo == 0 || u.hp <= 4 {
			if let af = ownAirfields.min(by: { a, b in
				a.position.stepDistance(to: p) < b.position.stepDistance(to: p)
			}) {
				return af.position
			}
		}

		let threatened = threatenedCities
		let goals = threatened.isEmpty ? enemyCities : threatened
		if goals.isEmpty {
			return units.firstMap { [country] i, e in
				e.country.team != country.team && isVisible(i.uid) ? position[i] : nil
			}
		}
		return goals.min(by: { a, b in
			a.stepDistance(to: p) < b.stepDistance(to: p)
		})
	}

	// MARK: - Purchase
	private var purchase: TacticalAction? {
		guard player.prestige >= 0x300 else { return nil }

		return buildings.firstMap { [country] _, b in
			guard b.country == country, unitsMap[b.position] < 0 else { return nil }

			let shop = shopUnits(at: b.position)
			guard !shop.isEmpty else { return nil }

			let pick = shop.enumerated().compactMap { i, t -> (Int, Int)? in
				guard t.cost <= player.prestige * 2 / 3 else { return nil }
				return (i, unitScore(t))
			}.max(by: { a, b in a.1 < b.1 })

			return pick.map { i, _ in .purchase(i, b.position) }
		}
	}

	private func unitScore(_ u: Unit) -> Int {
		var s = Int(u.softAtk) * 2
			+ Int(u.hardAtk) * 3
			+ Int(u.airAtk) * (enemyHasAir ? 4 : 1)
			+ Int(u.groundDef) * 2
			+ Int(u.airDef) * (enemyHasAir ? 2 : 1)
			+ Int(u.ini) * 3
			+ Int(u.mov)
			+ Int(u.rng) * 4
		if u[.art] { s += 12 }
		if u[.aa], enemyHasAir { s += 20 }
		if u[.transport] { s += 6 }
		if u[.supply] { s += 10 }
		if u[.radar] { s += 5 }
		if u[.aux] { s += 4 }
		s -= Int(u.cost / 64)
		return s
	}

	// MARK: - Resupply
	private func hasAirfield(_ xy: XY) -> Bool {
		xy.n4.firstMap { n in map[n] == .airfield ? n : nil } != nil
	}

	private func needsResupply(_ i: Int, _ u: Unit) -> Bool {
		guard u.untouched else { return false }
		guard cargo[i] == -1 || u[.transport] else { return false }
		if u.isAir, !hasAirfield(position[i]) { return false }
		return u.hp < 8 || (u.maxAmmo > 0 && u.ammo * 2 < u.maxAmmo)
	}

	private var resupply: TacticalAction? {
		units.firstMap { [country] i, u in
			u.country == country && needsResupply(i, u)
			? .resupply(i.uid) : nil
		}
	}

	// MARK: - Embark / Disembark
	private var embark: TacticalAction? {
		units.firstMap { [country] i, u in
			guard u.country == country, u.type == .soft, u.canMove,
				  cargo[i] == -1
			else { return nil }

			guard let target = objective(for: i.uid),
				  position[i].stepDistance(to: target) >= 4
			else { return nil }

			return position[i].n4.firstMap { xy -> TacticalAction? in
				guard let tid = uidAt(xy) else { return nil }
				let t = units[tid.index]
				return t.country == country && t[.transport] && cargo[tid.index] == -1
				? .embark(i.uid, tid) : nil
			}
		}
	}

	private var disembark: TacticalAction? {
		units.firstMap { [country] i, u in
			guard u.country == country, u[.transport], cargo[i] != -1 else { return nil }
			let cid = cargo[i]
			guard let target = objective(for: cid),
				  position[i].stepDistance(to: target) <= 2
			else { return nil }

			return position[i].n4.firstMap { xy -> TacticalAction? in
				map.contains(xy) && unitsMap[xy] < 0
				&& !map[xy].isRiver && map[xy] != .water
				? .disembark(i.uid, xy) : nil
			}
		}
	}

	// MARK: - Attack
	private var attack: TacticalAction? {
		var bestAttacker: UID = -1
		var bestTarget: UID = -1
		var bestScore = 0

		units.forEach { [country] i, u in
			guard u.country == country, u.canAttack, u.ammo > 0 else { return }
			if cargo[i] != -1, !u[.transport] { return }
			let src = i.uid

			units.forEach { j, t in
				guard t.country.team != u.country.team,
					  isVisible(j.uid),
					  unitCanHit(src, j.uid) else { return }
				let dst = j.uid
				let dmg = estimateDamage(attacker: src, defender: dst)
				guard dmg > 0 else { return }

				let canCounter = unitCanHit(dst, src) && (!u[.art] || t[.art])
				let counter: UInt8 = canCounter
					? estimateDamage(attacker: dst, defender: src)
					: 0

				let kill = dmg >= t.hp
				var score = Int(dmg) * Int(t.cost) - Int(counter) * Int(u.cost)
				if kill { score += Int(t.cost) * 5 }
				if t[.art] { score += Int(u.cost) * 2 }
				if t[.aa], u.isAir { score += Int(u.cost) * 4 }
				if t[.supply] { score += Int(u.cost) }
				if t.ammo == 0 { score += Int(t.cost) }

				if score > bestScore {
					bestScore = score
					bestAttacker = src
					bestTarget = dst
				}
			}
		}

		return bestScore > 0 ? .attack(bestAttacker, bestTarget) : nil
	}

	// MARK: - Retreat
	private var retreat: TacticalAction? {
		units.firstMap { [country] i, u in
			guard u.country == country, u.canMove else { return nil }
			if cargo[i] != -1, !u[.transport] { return nil }

			let critical = u.hp <= 4 || (u.maxAmmo > 0 && u.ammo == 0)
			guard critical else { return nil }

			let havens: [XY] = buildings.compactMap { _, b in
				b.country == country && (b.type == .airfield) == u.isAir ? b.position : nil
			}
			guard let goal = havens.min(by: { a, b in
				a.stepDistance(to: position[i]) < b.stepDistance(to: position[i])
			}) else { return nil }

			return pickMove(id: i.uid, toward: goal, defensive: true)
		}
	}

	// MARK: - Move
	private var move: TacticalAction? {
		units.firstMap { [country] i, u in
			guard u.country == country, u.canMove else { return nil }
			if cargo[i] != -1, !u[.transport] { return nil }

			guard let goal = objective(for: i.uid) else { return nil }
			let defensive = u[.art] || u.hp <= 6 || (u[.aa] && enemyHasAir)
			return pickMove(id: i.uid, toward: goal, defensive: defensive)
		}
	}

	private func pickMove(id: UID, toward target: XY, defensive: Bool) -> TacticalAction? {
		let mv = moves(for: id)
		let tiles = mv.set
		guard !tiles.isEmpty else { return nil }

		return tiles.max(by: { a, b in
			tileScore(at: a, for: id, toward: target, defensive: defensive)
			< tileScore(at: b, for: id, toward: target, defensive: defensive)
		}).map { .move(id, $0) }
	}

	private func tileScore(at xy: XY, for id: UID, toward target: XY, defensive: Bool) -> Int {
		let u = units[id.index]
		let team = u.country.team
		var score = 0

		score -= xy.stepDistance(to: target) * (defensive ? 3 : 6)

		if !u.isAir {
			score += Int(map[xy].baseEntrenchment) * (defensive ? 8 : 4)
			score += Int(map[xy].def(u.type)) * 2
			if u.type == .soft, map[xy] == .field { score -= 3 }
		}

		var supportBonus = 0
		var ownBuildingAdj = false
		let n4 = xy.n4
		for i in n4.indices {
			let n = n4[i]
			if let uid = uidAt(n) {
				let nu = units[uid.index]
				if nu.country.team == team {
					if nu[.art] { supportBonus += 4 }
					if nu[.aa], !u[.aa] { supportBonus += 3 }
					if nu[.supply] { supportBonus += 5 }
				}
			}
			if let b = buildings[n], b.country.team == team {
				ownBuildingAdj = true
				if b.type == .airfield, u.isAir { supportBonus += 6 }
				if b.type == .city { supportBonus += 2 }
			}
		}
		score += supportBonus

		if u.isAir, let b = buildings[xy], b.country.team == team, b.type == .airfield {
			score += 10
		}
		if !u.isAir, let b = buildings[xy], b.country.team == team {
			score += 3
		}

		var threat = 0
		units.forEach { j, e in
			guard e.country.team != team, isVisible(j.uid) else { return }
			let d = position[j].stepDistance(to: xy)
			let reach = Int(e.rng) * 2 + 1 + Int(e.mov) * 2 + 1
			if d <= reach {
				threat += Int(e.atk(u))
			}
		}
		score -= threat * (defensive ? 3 : 2)
		if ownBuildingAdj { score += threat / 3 }

		return score
	}
}
