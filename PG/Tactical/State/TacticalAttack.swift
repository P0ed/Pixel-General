extension TacticalState {

	func unitCanHit(_ src: UID, _ dst: UID) -> Bool {
		let su = units[src.index]
		let du = units[dst.index]
		let sp = position[src.index]
		let dp = position[dst.index]
		return sp.distance(to: dp) <= su.rng * 2 + 1
			&& su.atk(du) > 0
			&& (su.isAir ? su.ammo > 0 : true)
	}

	func support(trait: Traits, defender: UID, attacker: UID) -> UID? {
		position[defender.index].n8.firstMap { hx in
			return unitAt(hx).flatMap { u in
				u.country.team == units[defender.index].country.team && u[trait]
				? unitsMap[hx] : nil
			}
		}
	}

	mutating func fire(src: UID, dst: UID, defMod: Int8) {
		let (si, di) = (src.index, dst.index)
		let atkMod: Int8 = units[si].ammo == units[si].maxAmmo ? 1 : 0
		let atk = Int8(units[si].atk(units[di]) + units[si].stars) + atkMod
		let def = Int8(units[di].def(units[si]) + units[di].stars) + defMod

		let dif = atk - def
		let t1 = max(1, 6 - dif)
		let t2 = max(3, 15 - dif)
		let t3 = max(7, 22 - dif)
		let iniRound = units[si].ini > d20(.max(2)) ? 1 : 0 as UInt8
		let rounds = (units[si].hp + 3) / 3 + iniRound
		let crit = units[si][.crit]
		let evasion = units[di][.evasion]

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds
			.map { d in d > t3 ? 3 : d > t2 ? 2 : d > t1 ? 1 : 0 as UInt8 }
			.map { d in crit ? (d20() > 16 ? d * 2 : d) : d }
			.map { d in evasion ? (d20() > 16 ? 0 : d) : d }
		let dmg: UInt8 = dmgs.reduce(into: 0, +=)
		let targetPos = position[di]

		///# Logs
		let srcStr = units[si].shortDescription
		let dstStr = units[di].shortDescription
		let dmgLine = "ts: \([t1, t2, t3]) ds: \(ds) dmg: \(dmg) \(dmgs)"
		print("fire \(srcStr) -> \(dstStr)\natk: \(atk) def: \(def)\n\(dmgLine)")
		///# Logs

		units[si].ammo.decrement()
		let alive = damage(id: dst, dmg: dmg)
		units[si].exp.increment(by: 1 + dmg * (alive ? 3 : 5) / 7)
		if !alive { units[si].promote(using: &d20) }

		camera = targetPos
		events.add(.fire(src, dst, dmg, units[di].hp))
	}

	private mutating func damage(id: UID, dmg: UInt8) -> Bool {
		units[id.index].hp.decrement(by: dmg)
		if cargo[id.index] != -1 {
			units[cargo[id.index].index].hp.decrement(by: dmg)
		}
		let alive = units[id.index].alive
		if !alive {
			unitsMap[position[id.index]] = -1
			if cargo[id.index] != -1 {
				units[cargo[id.index].index].hp = 0x0
			}
		}
		return alive
	}

	private func encirclement(id: UID) -> Int8 {
		let team = units[id.index].country.team
		let enemies = position[id.index].n4.reduce(into: 0 as Int8) { r, xy in
			r += (unitAt(xy).map { u in u.country.team != team ? 1 : 0 } ?? 0)
		}
		return max(0, enemies - 1)
	}

	mutating func attack(src: UID, dst: UID, surprise: Bool = false) {
		let (si, di) = (src.index, dst.index)
		guard units[si].country == country,
			  units[si].country.team != units[di].country.team,
			  units[si].canAttack, unitCanHit(src, dst)
		else { return }

		let (su, du) = (units[si], units[di])
		let dt = map[position[di]]
		let dstDef = du.defMod(vs: su, in: dt) - encirclement(id: dst)

		let ruggedDefence: Bool = !surprise && su.noRetaliation ? false : (
			d20() + Int(su.ini + su.stars) * 2
		) < (
			Int(du.ent + du.ini + du.stars) * 2 + (surprise ? 10 : 0)
		)
		if ruggedDefence { print("Rugged Defence!") }
		units[si].ap.decrement()

		if !su.isAir, !du.isAir, !su.noRetaliation,
			let art = support(trait: .art, defender: dst, attacker: src) {
			fire(src: art, dst: src, defMod: su[.elite] ? 1 : 0)
		}
		if su.isAir, !du[.aa], let aa = support(trait: .aa, defender: dst, attacker: src) {
			fire(src: aa, dst: src, defMod: 0)
		}
		if !ruggedDefence, units[si].alive {
			fire(src: src, dst: dst, defMod: dstDef)
			units[di].ent.decrement()
		}
		if units[di].alive, units[si].alive, unitCanHit(dst, src), !su.noRetaliation || surprise {
			let srcDef = dt.closeCombatPenalty(su.type)
			+ (ruggedDefence ? -3 : 0)
			+ (du.ammo == 0 ? 5 : 0)
			fire(src: dst, dst: src, defMod: srcDef)
		}
		if ruggedDefence, units[si].alive {
			fire(src: src, dst: dst, defMod: dstDef)
			units[di].ent.decrement()
		}
		var hpRetreat: Bool {
			units[di].hp * 2 + units[di].ini + UInt8(d20()) < 20
			&& !units[si].noRetaliation
		}
		var airRetreat: Bool {
			!units[si].isAir && units[di].isAir
			&& buildings[position[di]].map {
				$0.country.team != units[di].country.team
			} ?? false
		}
		if units[di].alive, hpRetreat || airRetreat {
			retreat(uid: dst, from: position[si])
		}
		selectUnit(units[si].alive && units[si].hasActions ? src : .none)
	}

	private mutating func retreat(uid: UID, from xy: XY) {
		let p = position[uid.index]
		let pos = moves(for: uid).set.min(by: (p + p - xy).manhattanComparator)
		guard let pos, unitAt(pos) == nil else { return }

		unitsMap[position[uid.index]] = -1
		unitsMap[pos] = uid
		position[uid.index] = pos
		if cargo[uid.index] != -1 {
			position[cargo[uid.index].index] = pos
		}
		units[uid.index].ent = 0
		events.add(.move(uid, pos))
	}

	func estimateDamage(attacker: UID, defender: UID) -> UInt8 {
		let (a, d) = (units[attacker.index], units[defender.index])
		let atk = Int8(a.atk(d) + a.stars)
		let def = Int8(d.def(a) + d.stars) + map[position[defender.index]].def

		let rounds = Int(a.hp + 3) / 3
		let base = max(0, 127 + Int(atk - def) * 15)
		let crit = a[.crit] ? 120 : 100
		let evasion = d[.evasion] ? 80 : 100

		return UInt8(clamping: rounds * base * crit * evasion / 1_00_00_00)
	}
}
