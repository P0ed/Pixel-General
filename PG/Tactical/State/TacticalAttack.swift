extension TacticalState {

	func targets(unit: Unit) -> [(UID, Unit)] {
		!unit.canAttack ? [] : units.reduce(into: []) { r, i, u in
			if u.country.team != unit.country.team,
			   player.visible[u.position],
			   unit.canHit(unit: u)
			{
				r.append((i.uid, u))
			}
		}
	}

	func support(trait: Traits, defender: UID, attacker: UID) -> UID? {
		units[defender.index].position.n8.firstMap { hx in
			units[hx].flatMap { i, u in
				u.country.team == units[defender.index].country.team
				&& u[trait]
				? i : nil
			}
		}
	}

	mutating func fire(src: UID, dst: UID, defMod: Int) {
		let (si, di) = (src.index, dst.index)
		let atkMod = units[si].ammo == units[si].maxAmmo ? 1 : 0
		let atk = Int(units[si].atk(units[di]) + units[si].stars) + atkMod
		let def = Int(units[di].def(units[si]) + units[di].stars) + defMod

		let dif = atk - def
		let t1 = max(1, 6 - dif)
		let t2 = max(3, 15 - dif)
		let t3 = max(7, 22 - dif)
		let rounds = (units[si].hp + 3) / 3

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds.map { d in
			d > t3 ? 3 :
			d > t2 ? 2 :
			d > t1 ? 1 :
			0 as UInt8
		}
		let dmg: UInt8 = dmgs.reduce(into: 0, +=)
		let targetPos = units[di].position

		///# ˘˘Logs˘˘
		let srcStr = units[si].shortDescription
		let dstStr = units[di].shortDescription
		let dmgLine = "ts: \([t1, t2, t3]) ds: \(ds) dmg: \(dmg) \(dmgs)"
		print("fire \(srcStr) -> \(dstStr)\natk: \(atk) def: \(def)\n\(dmgLine)")
		///# ¯¯Logs¯¯

		units[si].ammo.decrement()
		let alive = damage(unit: dst, dmg: dmg)
		units[si].exp.increment(by: 1 + dmg * (alive ? 3 : 5) / 7)

		camera = targetPos
		events.add(.attack(src, dst, dmg, units[di].hp))
	}

	mutating func damage(unit: UID, dmg: UInt8) -> Bool {
		units[unit.index].hp.decrement(by: dmg)
		if !units[unit.index].alive {
			unitsMap[units[unit.index].position] = -1
			cargo[unit.index].hp = 0x0
			return false
		}
		return true
	}

	private func encirclement(uid: UID) -> Int {
		max(0, units[uid.index].position.n4
			.reduce(into: -1) { [country = units[uid.index].country] r, xy in
				units[xy].map { _, u in
					if u.country.team != country.team { r += 1 }
				}
			}
		)
	}

	mutating func attack(src: UID, dst: UID, surprise: Bool = false) {
		let (si, di) = (src.index, dst.index)
		guard units[si].country == country,
			  units[si].country.team != units[di].country.team,
			  units[si].canAttack, units[si].canHit(unit: units[di])
		else { return }

		let encirclement = encirclement(uid: dst)
		let srcStats = units[si]
		let dstStats = units[di]
		let srcTerrain = map[units[si].position]
		let dstTerrain = map[units[di].position]
		let srcRiver = srcTerrain.isRiver && !dstTerrain.isRiver ? 3 : 0
		let dstDef = Int(dstStats.ent) + dstTerrain.def - encirclement + srcRiver
		+ dstTerrain.closeCombatPenalty(dstStats.type) / 2

		let ruggedDefence: Bool = !surprise && srcStats.noRetaliation ? false : (
			d20() + Int(srcStats.ini + srcStats.stars) * 2
		) < (
			Int(dstStats.ent + dstStats.ini + dstStats.stars) * 2 + (surprise ? 10 : 0)
		)
		if ruggedDefence { print("Rugged Defence!") }
		units[si].ap &= 0b01

		if !srcStats.isAir, !dstStats.isAir, !srcStats.noRetaliation,
			let art = support(trait: .art, defender: dst, attacker: src) {
			fire(src: art, dst: src, defMod: srcStats[.elite] ? 1 : 0)
		}
		if srcStats.isAir, !dstStats[.aa], let aa = support(trait: .aa, defender: dst, attacker: src) {
			fire(src: aa, dst: src, defMod: 0)
		}
		if !ruggedDefence, units[si].alive {
			fire(src: src, dst: dst, defMod: dstDef)
			units[di].ent.decrement()
		}
		if units[di].alive, units[si].alive,
		   units[di].canHit(unit: units[si]),
		   !srcStats.noRetaliation || surprise {

			let srcDef = dstTerrain.closeCombatPenalty(srcStats.type)
			+ (ruggedDefence ? -3 : 0)
			+ (dstStats.ammo == 0 ? 5 : 0)
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
			&& buildings[units[di].position].map {
				$0.country.team != units[di].country.team
			} ?? false
		}
		if units[di].alive, hpRetreat || airRetreat {
			retreat(uid: dst, from: units[si].position)
		}
		selectUnit(units[si].alive && units[si].hasActions ? src : .none)
	}

	mutating func retreat(uid: UID, from xy: XY) {
		let p = units[uid.index].position
		let pos = moves(for: units[uid.index]).set.min(by: (p + p + p - xy - xy).manhattanComparator)
		guard let pos, unitAt(pos) == nil else { return }

		unitsMap[units[uid.index].position] = -1
		unitsMap[pos] = uid
		units[uid.index].position = pos
		units[uid.index].ent = 0
		events.add(.move(uid, p, pos))
	}
}
