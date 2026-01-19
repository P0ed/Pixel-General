extension TacticalState {

	func targets(unit: Unit) -> [(UID, Unit)] {
		!unit.canAttack ? [] : units.reduce(into: []) { r, i, u in
			if u.country.team != unit.country.team,
			   player.visible[u.position],
			   unit.canHit(unit: u)
			{
				r.append((i, u))
			}
		}
	}

	func support(trait: Trait, defender: UID, attacker: UID) -> UID? {
		units[defender].position.n8.firstMap { hx in
			units[hx].flatMap { i, u in
				u.country.team == units[defender].country.team
				&& u.stats[trait]
				? i : nil
			}
		}
	}

	mutating func fire(src: UID, dst: UID, defMod: Int) {
		let atkMod = units[src].stats.ammo == 0x7 ? 1 : 0
		let atk = Int(units[src].stats.atk(units[dst].stats) + units[src].stats.stars) + atkMod
		let def = Int(units[dst].stats.def(units[src].stats) + units[dst].stats.stars) + defMod

		let dif = atk - def
		let t1 = max(1, 7 - dif)
		let t2 = max(3, 15 - dif)
		let t3 = max(7, 22 - dif)
		let rounds = (units[src].stats.hp + 3) / 3

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds.map { d in
			d > t3 ? 3 :
			d > t2 ? 2 :
			d > t1 ? 1 :
			0 as UInt8
		}
		let dmg: UInt8 = dmgs.reduce(into: 0, +=)
		let targetPos = units[dst].position

		///# ˘˘Logs˘˘
		let srcStr = units[src].shortDescription
		let dstStr = units[dst].shortDescription
		let dmgLine = "ts: \([t1, t2, t3]) ds: \(ds) dmg: \(dmg) \(dmgs)"
		print("fire \(srcStr) -> \(dstStr)\natk: \(atk) def: \(def)\n\(dmgLine)")
		///# ¯¯Logs¯¯

		units[src].stats.ammo.decrement()
		units[dst].stats.hp.decrement(by: dmg)
		let alive = units[dst].alive
		units[src].stats.exp.increment(by: alive ? dmg : dmg * 2)
		if !alive { unitsMap[targetPos] = -1 }

		camera = targetPos
		events.add(.attack(src, dst, dmg, units[dst].stats.hp))
	}

	private func encirclement(uid: UID) -> Int {
		max(0, units[uid].position.n4
			.reduce(into: -1) { [country = units[uid].country] r, xy in
				units[xy].map { _, u in
					if u.country.team != country.team { r += 1 }
				}
			}
		)
	}

	mutating func attack(src: UID, dst: UID, surprise: Bool = false) {
		guard units[src].country == country,
			  units[src].country.team != units[dst].country.team,
			  units[src].canAttack, units[src].canHit(unit: units[dst])
		else { return }

		let encirclement = encirclement(uid: dst)
		let srcStats = units[src].stats
		let dstStats = units[dst].stats
		let srcTerrain = map[units[src].position]
		let dstTerrain = map[units[dst].position]
		let srcRiver = -min(0, srcTerrain.def)
		let dstDef = Int(dstStats.ent) + dstTerrain.def - encirclement + srcRiver
		let ruggedDefence: Bool = !surprise && srcStats.noRetaliation ? false : (
			d20() + Int(srcStats.ini + srcStats.stars) * 2
		) < (
			Int(dstStats.ent + dstStats.ini + dstStats.stars) * 2 + (surprise ? 10 : 0)
		)
		if ruggedDefence { print("Rugged Defence!") }
		units[src].stats.ap.decrement()

		if !srcStats.isAir, !dstStats.isAir, !srcStats.noRetaliation,
			let art = support(trait: .art, defender: dst, attacker: src) {
			fire(src: art, dst: src, defMod: srcStats[.hardcore] ? 1 : 0)
		}
		if srcStats.isAir, let aa = support(trait: .aa, defender: dst, attacker: src) {
			fire(src: aa, dst: src, defMod: 0)
		}
		if !ruggedDefence, units[src].alive {
			fire(src: src, dst: dst, defMod: dstDef)
			units[dst].stats.ent.decrement()
		}
		if units[dst].alive, units[src].alive,
		   units[dst].canHit(unit: units[src]),
		   !srcStats.noRetaliation || surprise {

			let srcDef = (dstStats.isAir ? 0 : dstTerrain.closeCombatPenalty(srcStats.type))
			+ (ruggedDefence ? -3 : 0)
			fire(src: dst, dst: src, defMod: srcDef)
		}
		if ruggedDefence, units[src].alive {
			fire(src: src, dst: dst, defMod: dstDef)
			units[dst].stats.ent.decrement()
		}
		selectUnit(units[src].alive && units[src].hasActions ? src : .none)
	}
}

extension Stats {

	var noRetaliation: Bool { self[.art] }
}
