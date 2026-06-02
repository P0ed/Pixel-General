extension TacticalState {

	// MARK: - Entry point

	/// One AI action. The plan is (re)built whenever the turn changes; the
	/// generators below then translate that plan into a single concrete action,
	/// applied in priority order: spend money, patch up, shoot, ferry, manoeuvre.
	func axis(ai: inout AI) -> TacticalAction {
		if ai.turn != turn { plan(&ai) }

		if let act = purchase { return act }
		if let act = resupply { return act }
		if let act = bestAttack() { return act }
		if let act = disembark { return act }
		if let act = embark { return act }
		if let act = bestMove(ai) { return act }
		return .end
	}

	// MARK: - Planning
	//
	// Strategy: the battle is won by holding settlements (a player with none is
	// eliminated). So the AI first pulls broken units back to heal, then garrisons
	// any of its own towns an enemy can reach, and finally throws everything else
	// at the nearest enemy settlement — infantry/armor to capture, artillery and
	// AA to shoot the approach, supply trailing behind.

	private func plan(_ ai: inout AI) {
		ai = AI(turn: turn)

		let roster = roster
		guard !roster.isEmpty else { return }

		let enemies = visibleEnemies
		let havens = ownSettlements
		var claimed: UInt128 = 0

		// 1) Pull damaged or empty units back to a matching haven.
		for uid in roster {
			let u = units[uid]
			guard u.hp <= 3 || (u.maxAmmo > 0 && u.ammo == 0) else { continue }
			let air = u.isAir
			guard let haven = havens
				.filter({ (map[$0] == .airfield) == air })
				.min(by: { position[uid].stepDistance(to: $0) < position[uid].stepDistance(to: $1) })
			else { continue }
			ai.role[uid.index] = .retreat
			ai.target[uid.index] = haven
			claimed |= 1 << uid.rawValue
		}

		// 2) Garrison threatened settlements with the nearest spare ground units.
		let threatened = havens
			.map { ($0, threat(at: $0, from: enemies)) }
			.filter { $0.1 > 0 }
			.sorted { a, b in a.1 != b.1 ? a.1 > b.1 : map[a.0].income > map[b.0].income }

		for (city, t) in threatened {
			let need = t >= 14 ? 2 : 1
			for _ in 0 ..< need {
				var pick: UID = .none
				var pickKey = (Int.max, Int.max)
				for uid in roster where claimed & (1 << uid.rawValue) == 0 {
					let u = units[uid]
					guard garrison(u) else { continue }
					let key = (garrisonPriority(u), position[uid].stepDistance(to: city))
					if key < pickKey { pickKey = key; pick = uid }
				}
				guard pick != .none else { break }
				ai.role[pick.index] = .defend
				ai.target[pick.index] = city
				claimed |= 1 << pick.rawValue
			}
		}

		// 3) Everything else goes on the offensive.
		for uid in roster where claimed & (1 << uid.rawValue) == 0 {
			let u = units[uid]
			let p = position[uid]
			if u.type == .supply {
				ai.role[uid.index] = .support
				ai.target[uid.index] = nearestFriendlyCombat(to: p, exclude: uid) ?? p
			} else if u.isArt || u.isAA || u.isAir {
				ai.role[uid.index] = .hunt
				ai.target[uid.index] = frontObjective(from: p, enemies) ?? p
			} else {
				ai.role[uid.index] = .attack
				ai.target[uid.index] = frontObjective(from: p, enemies) ?? p
			}
		}
	}

	private func garrison(_ u: Unit) -> Bool {
		u.type == .inf || u.isArmor || u.isAA
	}

	private func garrisonPriority(_ u: Unit) -> Int {
		u.type == .inf ? 0 : u.isArmor ? 1 : 2
	}

	/// Rough enemy pressure on a tile: ground attackers that could reach it in
	/// about a turn, weighted by raw firepower.
	private func threat(at xy: XY, from enemies: [(UID, XY)]) -> Int {
		var t = 0
		for (uid, p) in enemies {
			let e = units[uid]
			guard !e.isAir else { continue }
			let reach = Int(e.mov) * 2 + 1 + Int(e.rng) * 2 + 1
			if p.stepDistance(to: xy) <= reach + 2 {
				t += Int(e.softAtk) + Int(e.hardAtk) + 4
			}
		}
		return t
	}

	// MARK: - Rosters & objectives

	/// Our alive, controllable units (carried cargo is skipped unless it is a
	/// loaded transport, which still acts as one unit).
	private var roster: [UID] {
		units.compactMapAlive { [country] i, u in
			u.country == country && !offMap(unit: i.uid) ? i.uid : nil
		}
	}

	private var visibleEnemies: [(UID, XY)] {
		units.compactMapAlive { [country] i, u in
			u.country.team != country.team && isVisible(i.uid) ? (i.uid, position[i]) : nil
		}
	}

	private var ownSettlements: [XY] {
		map.indices.compactMap { [country] xy in
			map[xy].isSettlement && control[xy] == country ? xy : nil
		}
	}

	private var enemySettlements: [XY] {
		map.indices.compactMap { [country] xy in
			map[xy].isSettlement && control[xy].team != country.team ? xy : nil
		}
	}

	/// The point a unit should advance on: the nearest enemy settlement, or
	/// failing that the nearest visible enemy unit.
	private func frontObjective(from p: XY, _ enemies: [(UID, XY)]) -> XY? {
		if let c = enemySettlements.min(by: { p.stepDistance(to: $0) < p.stepDistance(to: $1) }) {
			return c
		}
		return enemies.min(by: { p.stepDistance(to: $0.1) < p.stepDistance(to: $1.1) })?.1
	}

	private func nearestFriendlyCombat(to p: XY, exclude: UID) -> XY? {
		var best: XY? = nil
		var bd = Int.max
		units.forEachAlive { [country] i, u in
			guard u.country == country, i.uid != exclude, u.type != .supply, !u.isAir else { return }
			let d = position[i].stepDistance(to: p)
			if d < bd { bd = d; best = position[i] }
		}
		return best
	}

	private func hasAirfield(_ xy: XY) -> Bool {
		map.indices.contains { [country] p in
			map[p] == .airfield && control[p] == country
			&& p.manhattanDistance(to: xy) <= 1
		}
	}

	private var enemyHasAir: Bool {
		units.firstMapAlive { [country] i, u in
			u.country.team != country.team && u.isAir && isVisible(i.uid) ? true : nil
		} ?? false
	}

	private var ownSupplyCount: Int {
		units.reduceAlive(into: 0) { [country] r, _, u in
			if u.country == country, u.type == .supply { r += 1 }
		}
	}

	private var ownAACount: Int {
		units.reduceAlive(into: 0) { [country] r, _, u in
			if u.country == country, u.isAA { r += 1 }
		}
	}

	// MARK: - Purchase

	private var purchase: TacticalAction? {
		guard player.prestige >= 0x280 else { return nil }

		let enemies = visibleEnemies
		let buildable = map.indices.filter { [country] xy in
			map[xy].isSettlement && control[xy] == country && unitsMap[xy] == .none
		}
		.sorted { frontDistance($0, enemies) < frontDistance($1, enemies) }

		let enemyAir = enemyHasAir
		let needSupply = ownSupplyCount == 0
		let needAA = enemyAir && ownAACount == 0

		for spot in buildable {
			let shop = shopUnits(at: spot)
			let pick = shop.enumerated().compactMap { i, t -> (Int, Int)? in
				guard t.cost <= player.prestige * 2 / 3 else { return nil }
				var s = score(t, enemyAir: enemyAir)
				if needSupply, t.type == .supply { s += 50 }
				if needAA, t.isAA { s += 50 }
				return (i, s)
			}.max(by: { a, b in a.1 < b.1 })
			if let pick { return .purchase(pick.0, spot) }
		}
		return nil
	}

	/// Distance from a buildable tile to the front (nearest enemy settlement,
	/// else nearest visible enemy). Used to spawn units where they are needed.
	private func frontDistance(_ xy: XY, _ enemies: [(UID, XY)]) -> Int {
		if let d = enemySettlements.map({ xy.stepDistance(to: $0) }).min() { return d }
		return enemies.map { xy.stepDistance(to: $0.1) }.min() ?? 0
	}

	private func score(_ u: Unit, enemyAir: Bool) -> Int {
		var s = Int(u.softAtk) * 4
			+ Int(u.hardAtk) * 4
			+ Int(u.airAtk) * (enemyAir ? 5 : 2)
			+ Int(u.groundDef) * 2
			+ Int(u.airDef) * (enemyAir ? 3 : 2)
			+ Int(u.ini) * 4
			+ Int(u.mov) * 3
			+ Int(u.rng) * 5
		if u.isArt { s += 15 }
		if u.isAA, enemyAir { s += 18 }
		if u.isAir { s += 8 }
		if u[.transport] { s += 6 }
		if u.type == .supply { s += 8 }
		if u[.aux] { s += 12 }
		s -= Int(u.cost / 64)
		return s
	}

	// MARK: - Resupply

	private func needsResupply(_ i: Int, _ u: Unit) -> Bool {
		guard u.untouched, !offMap(unit: i.uid) else { return false }
		if u.isAir, !hasAirfield(position[i]) { return false }
		return u.hp < 6 || (u.maxAmmo > 0 && u.ammo == 0)
	}

	private var resupply: TacticalAction? {
		units.firstMapAlive { [country] i, u in
			u.country == country && needsResupply(i, u) ? .resupply(i.uid) : nil
		}
	}

	// MARK: - Transport

	private var embark: TacticalAction? {
		let enemies = visibleEnemies
		return units.firstMapAlive { [country] i, u in
			guard u.country == country, u.transportable, u.canMove, cargo[i] == .none else { return nil }
			guard let target = frontObjective(from: position[i], enemies) else { return nil }
			guard position[i].stepDistance(to: target) >= 3 * Int(u.mov) else { return nil }

			return position[i].n4.firstMap { xy -> TacticalAction? in
				guard let tid = uidAt(xy) else { return nil }
				let t = units[tid]
				return t.country == country && t[.transport] && cargo[tid] == .none
					&& canEmbarkType(unit: u, transport: t)
					? .embark(i.uid, tid) : nil
			}
		}
	}

	private var disembark: TacticalAction? {
		let enemies = visibleEnemies
		return units.firstMapAlive { [country] i, u in
			guard u.country == country, u[.transport], cargo[i] != .none else { return nil }
			guard let target = frontObjective(from: position[i], enemies),
				  position[i].stepDistance(to: target) <= 4
			else { return nil }
			return position[i].n4.firstMap { xy -> TacticalAction? in
				map.contains(xy) && unitsMap[xy] == .none
				&& !map[xy].isRiver && map[xy] != .water
				? .disembark(i.uid, xy) : nil
			}
		}
	}

	// MARK: - Attack

	private func attackPriority(_ u: Unit) -> Int {
		if u.isArt { 0 } else if u.isAir { 1 } else if u.isAA { 2 } else if u.isArmor { 3 } else { 4 }
	}

	/// Artillery softens first (it takes no counter), then air, AA, armor and
	/// finally infantry mop up — so each shot lands against the weakest target.
	private func attackOrder() -> [UID] {
		roster.sorted { a, b in
			let pa = attackPriority(units[a]), pb = attackPriority(units[b])
			return pa != pb ? pa < pb : a.rawValue < b.rawValue
		}
	}

	private func bestAttack() -> TacticalAction? {
		for uid in attackOrder() {
			let u = units[uid]
			guard u.canAttack, u.ammo > 0, !offMap(unit: uid) else { continue }

			var bestTarget: UID = .none
			var bestScore = 0
			units.forEachAlive { j, t in
				guard t.country.team != u.country.team,
					  isVisible(j.uid),
					  unitCanHit(uid, j.uid) else { return }
				let dmg = estimateDamage(attacker: uid, defender: j.uid)
				guard dmg > 0 else { return }
				let score = attackValue(uid, j.uid, dmg: dmg, u, t)
				if score > bestScore { bestScore = score; bestTarget = j.uid }
			}
			if bestTarget != .none { return .attack(uid, bestTarget) }
		}
		return nil
	}

	private func attackValue(_ uid: UID, _ tid: UID, dmg: UInt8, _ u: Unit, _ t: Unit) -> Int {
		let canCounter = unitCanHit(tid, uid) && (!u.isArt || t.isArt)
		let counter: UInt8 = canCounter ? estimateDamage(attacker: tid, defender: uid) : 0
		let kill = dmg >= t.hp

		var score = Int(dmg) * Int(t.cost) * 3 / 2 - Int(counter) * Int(u.cost) / 2
		if kill { score += Int(t.cost) * 10 }
		if t.isArt { score += Int(u.cost) * 3 }
		if t.isAA, u.isAir { score += Int(u.cost) * 5 }
		if t.type == .supply { score += Int(u.cost) * 2 }
		if t.ammo == 0 { score += Int(t.cost) * 2 }
		// Dislodge enemies sitting on one of our settlements before they flip it.
		if map[position[tid]].isSettlement, control[position[tid]].team == u.country.team {
			score += Int(t.cost) * 4
		}
		return score
	}

	// MARK: - Move

	private func roleRank(_ role: AI.Role) -> Int {
		switch role {
		case .retreat: 0
		case .defend: 1
		case .hunt: 2
		case .attack: 3
		case .support: 4
		case .idle: 5
		}
	}

	private func bestMove(_ ai: AI) -> TacticalAction? {
		let order = roster.sorted { a, b in
			let ra = roleRank(ai.role[a.index]), rb = roleRank(ai.role[b.index])
			return ra != rb ? ra < rb : a.rawValue < b.rawValue
		}
		for uid in order {
			let u = units[uid]
			guard u.canMove, !offMap(unit: uid) else { continue }
			if let m = moveByRole(uid, ai) { return m }
		}
		return nil
	}

	private func moveByRole(_ uid: UID, _ ai: AI) -> TacticalAction? {
		let u = units[uid]
		let p = position[uid]
		switch ai.role[uid.index] {
		case .retreat:
			return pick(uid, toward: ai.target[uid.index], defensive: true)
		case .defend:
			return pick(uid, toward: ai.target[uid.index], defensive: true)
		case .support:
			let anchor = nearestFriendlyCombat(to: p, exclude: uid) ?? ai.target[uid.index]
			return pick(uid, toward: anchor, defensive: true)
		case .hunt:
			guard let goal = frontObjective(from: p, visibleEnemies) else { return nil }
			return pick(uid, toward: goal, defensive: u.isArt || u.hp <= 6)
		case .attack:
			guard let goal = frontObjective(from: p, visibleEnemies) else { return nil }
			return pick(uid, toward: goal, defensive: u.hp <= 4)
		case .idle:
			guard let goal = frontObjective(from: p, visibleEnemies) else { return nil }
			return pick(uid, toward: goal, defensive: false)
		}
	}

	/// Choose the best reachable tile toward `target`. Returns `nil` when staying
	/// put scores at least as high as any move — this avoids no-op moves (which
	/// would otherwise loop forever) and refuses to step into a worse position.
	private func pick(_ id: UID, toward target: XY, defensive: Bool) -> TacticalAction? {
		let mv = moves(for: id)
		let here = position[id]
		var best: XY? = nil
		var bestScore = tileScore(at: here, for: id, toward: target, defensive: defensive)
		for xy in mv.set where xy != here {
			let s = tileScore(at: xy, for: id, toward: target, defensive: defensive)
			if s > bestScore { bestScore = s; best = xy }
		}
		return best.map { .move(id, $0) }
	}

	private func tileScore(at xy: XY, for id: UID, toward target: XY, defensive: Bool) -> Int {
		let u = units[id]
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
				let nu = units[uid]
				if nu.country.team != team, isVisible(uid) {
					attackBonus += Int(u.atk(nu)) * 3
				} else if nu.country.team == team {
					if nu.isArt { support += 3 }
					if nu.isAA, !u.isAA { support += 2 }
					if nu.type == .supply { support += 4 }
				}
			}
			if map[n] == .airfield, control[n].team == team, u.isAir {
				support += 4
			}
		}
		score += attackBonus + support

		if u.isAir, map[xy] == .airfield, control[xy].team == team {
			score += 6
		}
		// Standing on an enemy settlement captures it — the whole point of the game.
		if !u.isAir, map[xy].isSettlement, control[xy].team != team {
			score += 60
		}

		var threat = 0
		units.forEachAlive { j, e in
			guard e.country.team != team, isVisible(j.uid) else { return }
			let d = position[j].stepDistance(to: xy)
			let reach = Int(e.rng) * 2 + 1 + Int(e.mov) * 2 + 1
			if d <= reach { threat += Int(e.atk(u)) }
		}
		score -= threat * (defensive ? 3 : 1)

		return score
	}
}
