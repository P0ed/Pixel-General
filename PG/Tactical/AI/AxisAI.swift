extension TacticalState {

	func axisAI(ai: inout AI) -> TacticalAction {
		if ai.turn != turn { populateQueues(&ai) }

		if let act = purchase { return act }
		if let act = resupply { return act }
		if let act = attack(ai) { return act }
		if let act = disembark { return act }
		if let act = embark { return act }
		if let act = move(ai) { return act }
		return .end
	}

	// MARK: - Priority queues (cached in `ai`)

	private func priority(_ u: Unit) -> Int {
		if u[.aa] { 0 }
		else if u.isAir { 1 }
		else if u[.art]  { 2 }
		else { 3 }
	}

	private func populateQueues(_ ai: inout AI) {
		ai = AI(turn: turn)

		var ownUnits: CArray<32, UID> = .init(tail: -1)
		units.forEach { [country] i, u in
			if u.country == country, cargo[i] == -1 || u[.transport] {
				ownUnits.add(i.uid)
			}
		}
		guard !ownUnits.isEmpty else { return }

		var claimed: UInt128 = 0
		let cities = ownCities
		let cityCount = min(8, cities.count)

		for c in 0 ..< cityCount {
			let cityPos = cities[c].position
			let base = c * 4

			if let pick = ownUnits.compactMap({ (_, uid) -> (UID, Int)? in
				guard claimed & 1 << uid == 0,
					  units[uid.index].type == .soft, !units[uid.index][.art], !units[uid.index][.aa]
				else { return nil }
				return (uid, position[uid.index].stepDistance(to: cityPos))
			}).min(by: { a, b in a.1 < b.1 }) {
				ai.defenders[base + 0] = pick.0
				claimed |= 1 << pick.0
			}

			if let pick = ownUnits.compactMap({ (_, uid) -> (UID, Int, Bool)? in
				guard claimed & 1 << uid == 0, units[uid.index][.art] else { return nil }
				return (uid, position[uid.index].stepDistance(to: cityPos), units[uid.index].type == .soft)
			}).min(by: { a, b in
				a.2 != b.2 ? a.2 : a.1 < b.1
			}) {
				ai.defenders[base + 1] = pick.0
				claimed |= 1 << pick.0
			}

			if let pick = ownUnits.compactMap({ (_, uid) -> (UID, Int)? in
				guard claimed & 1 << uid == 0, units[uid.index][.aa] else { return nil }
				return (uid, position[uid.index].stepDistance(to: cityPos))
			}).min(by: { a, b in a.1 < b.1 }) {
				ai.defenders[base + 2] = pick.0
				claimed |= 1 << pick.0
			}

			if let pick = ownUnits.compactMap({ (_, uid) -> (UID, Int)? in
				guard claimed & 1 << uid == 0, units[uid.index].isArmor else { return nil }
				return (uid, position[uid.index].stepDistance(to: cityPos))
			}).min(by: { a, b in a.1 < b.1 }) {
				ai.defenders[base + 3] = pick.0
				claimed |= 1 << pick.0
			}
		}

		var order: [(Int, UID)] = []
		ownUnits.forEach { _, uid in
			if claimed & 1 << uid == 0 {
				order.append((priority(units[uid.index]), uid))
			}
		}
		order.sort { a, b in
			a.0 != b.0 ? a.0 < b.0 : a.1 < b.1
		}
		let n = min(order.count, 32)
		for k in 0 ..< n { ai.attackers[k] = order[k].1 }
	}

	private func activeQueue(_ ai: borrowing AI) -> [UID] {
		var out: [UID] = []
		for k in 0 ..< 32 {
			let uid = ai.attackers[k]
			if uid == -1 { continue }
			let i = uid.index
			guard i >= 0, i < units.count else { continue }
			let u = units[i]
			if u.alive, u.country == country { out.append(uid) }
		}
		for k in 0 ..< 32 {
			let uid = ai.defenders[k]
			if uid == -1 { continue }
			let i = uid.index
			guard i >= 0, i < units.count else { continue }
			let u = units[i]
			if u.alive, u.country == country { out.append(uid) }
		}
		return out
	}

	private func defenderCity(_ ai: borrowing AI, _ uid: UID) -> XY? {
		let cities = ownCities
		for k in 0 ..< 32 where ai.defenders[k] == uid {
			let idx = k / 4
			if idx < cities.count { return cities[idx].position }
		}
		return nil
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

	private func hasAirfield(_ xy: XY) -> Bool {
		xy.n4.firstMap { n in map[n] == .airfield ? n : nil } != nil
	}

	private var enemyHasAir: Bool {
		units.firstMap { [country] i, u in
			u.country.team != country.team && u.isAir && isVisible(i.uid) ? true : nil
		} ?? false
	}

	private func objective(for uid: UID) -> XY? {
		let u = units[uid.index]
		let p = position[uid.index]

		if u.isAir, u.ammo == 0, u.hp < 6 {
			if let af = ownAirfields.min(by: { a, b in
				a.position.stepDistance(to: p) < b.position.stepDistance(to: p)
			}) {
				return af.position
			}
		}

		if let c = enemyCities.min(by: { a, b in
			a.stepDistance(to: p) < b.stepDistance(to: p)
		}) { return c }

		var best: XY? = nil
		var bestD = Int.max
		units.forEach { [country] i, e in
			if e.country.team != country.team, isVisible(i.uid) {
				let d = position[i].stepDistance(to: p)
				if d < bestD { bestD = d; best = position[i] }
			}
		}
		return best
	}

	// MARK: - Purchase

	private var purchase: TacticalAction? {
		guard player.prestige >= 0x300 else { return nil }

		return buildings.firstMap { [country] _, b in
			guard b.country == country, unitsMap[b.position] < 0 else { return nil }
			let shop = shopUnits(at: b.position)
			guard !shop.isEmpty else { return nil }

			let pick = shop.enumerated().compactMap { i, t -> (Int, Int)? in
				guard t.cost <= player.prestige * 3 / 4 else { return nil }
				return (i, score(t))
			}.max(by: { a, b in a.1 < b.1 })

			return pick.map { i, _ in .purchase(i, b.position) }
		}
	}

	private func score(_ u: Unit) -> Int {
		var s = Int(u.softAtk) * 4
			+ Int(u.hardAtk) * 5
			+ Int(u.airAtk) * (enemyHasAir ? 5 : 2)
			+ Int(u.groundDef)
			+ Int(u.airDef) * (enemyHasAir ? 2 : 1)
			+ Int(u.ini) * 4
			+ Int(u.mov) * 3
			+ Int(u.rng) * 5
		if u[.art] { s += 14 }
		if u[.aa], enemyHasAir { s += 18 }
		if u.isAir { s += 8 }
		if u[.transport] { s += 4 }
		if u[.supply] { s += 6 }
		if u[.aux] { s += 6 }
		s -= Int(u.cost / 80)
		return s
	}

	// MARK: - Resupply

	private func needsResupply(_ i: Int, _ u: Unit) -> Bool {
		guard u.untouched else { return false }
		guard cargo[i] == -1 || u[.transport] else { return false }
		if u.isAir, !hasAirfield(position[i]) { return false }
		return u.hp < 6 || (u.maxAmmo > 0 && u.ammo == 0)
	}

	private var resupply: TacticalAction? {
		units.firstMap { [country] i, u in
			u.country == country && needsResupply(i, u) ? .resupply(i.uid) : nil
		}
	}

	// MARK: - Embark / Disembark

	private var embark: TacticalAction? {
		units.firstMap { [country] i, u in
			guard u.country == country, u.type == .soft, u.canMove, cargo[i] == -1
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

	// MARK: - Attack (priority-ordered)

	private func attack(_ ai: borrowing AI) -> TacticalAction? {
		for uid in activeQueue(ai) {
			let u = units[uid.index]
			guard u.canAttack, u.ammo > 0 else { continue }
			if cargo[uid.index] != -1, !u[.transport] { continue }

			var bestTarget: UID = -1
			var bestScore = 0
			units.forEach { j, t in
				guard t.country.team != u.country.team,
					  isVisible(j.uid),
					  unitCanHit(uid, j.uid) else { return }
				let dmg = estimateDamage(attacker: uid, defender: j.uid)
				guard dmg > 0 else { return }

				let canCounter = unitCanHit(j.uid, uid) && (!u[.art] || t[.art])
				let counter: UInt8 = canCounter
					? estimateDamage(attacker: j.uid, defender: uid)
					: 0

				let kill = dmg >= t.hp
				var s = Int(dmg) * Int(t.cost) * 3 / 2
					  - Int(counter) * Int(u.cost) / 2
				if kill { s += Int(t.cost) * 10 }
				if t[.art] { s += Int(u.cost) * 3 }
				if t[.aa], u.isAir { s += Int(u.cost) * 5 }
				if t[.supply] { s += Int(u.cost) * 2 }
				if t.ammo == 0 { s += Int(t.cost) * 2 }

				if s > bestScore {
					bestScore = s
					bestTarget = j.uid
				}
			}
			if bestScore > 0 { return .attack(uid, bestTarget) }
		}
		return nil
	}

	// MARK: - Move (priority-ordered)

	private func move(_ ai: borrowing AI) -> TacticalAction? {
		for uid in activeQueue(ai) {
			let u = units[uid.index]
			guard u.canMove else { continue }
			if cargo[uid.index] != -1, !u[.transport] { continue }

			if let city = defenderCity(ai, uid) {
				let p = position[uid.index]
				if p.stepDistance(to: city) <= 1 { continue }
				if let m = pick(id: uid, toward: city, defensive: true) { return m }
				continue
			}

			let critical = u.hp <= 3 || (u.maxAmmo > 0 && u.ammo == 0)
			if critical {
				let havens: [XY] = buildings.compactMap { [country] _, b in
					b.country == country && (b.type == .airfield) == u.isAir ? b.position : nil
				}
				if let goal = havens.min(by: { a, b in
					a.stepDistance(to: position[uid.index]) < b.stepDistance(to: position[uid.index])
				}), let m = pick(id: uid, toward: goal, defensive: true) {
					return m
				}
			}

			guard let goal = objective(for: uid) else { continue }
			let defensive = u[.art] || u.hp <= 4
			if let m = pick(id: uid, toward: goal, defensive: defensive) {
				return m
			}
		}
		return nil
	}

	private func pick(id: UID, toward target: XY, defensive: Bool) -> TacticalAction? {
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

		score -= xy.stepDistance(to: target) * (defensive ? 4 : 12)

		if !u.isAir {
			score += Int(map[xy].baseEntrenchment) * (defensive ? 6 : 2)
			score += Int(map[xy].def(u.type))
		}

		let n4 = xy.n4
		var attackBonus = 0
		var support = 0
		for k in n4.indices {
			let n = n4[k]
			if let uid = uidAt(n) {
				let nu = units[uid.index]
				if nu.country.team != team, isVisible(uid) {
					attackBonus += Int(u.atk(nu)) * 3
				} else if nu.country.team == team {
					if nu[.art] { support += 3 }
					if nu[.aa], !u[.aa] { support += 2 }
					if nu[.supply] { support += 4 }
				}
			}
			if let b = buildings[n], b.country.team == team, b.type == .airfield, u.isAir {
				support += 4
			}
		}
		score += attackBonus + support

		if u.isAir, let b = buildings[xy], b.country.team == team, b.type == .airfield {
			score += 6
		}
		if !u.isAir, let b = buildings[xy], b.country.team != team, b.type == .city {
			score += 50
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
		score -= threat * (defensive ? 3 : 1)

		return score
	}
}
