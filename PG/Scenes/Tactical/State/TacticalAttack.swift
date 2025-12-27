extension TacticalState {

	func targets(unit: Unit) -> [(UID, Unit)] {
		!unit.canAttack ? [] : units.compactMap { i, u in
			u.country.team != unit.country.team
			&& player.visible[u.position]
			&& unit.canHit(unit: u)
			? (i, u) : nil
		}
	}

	func support(request: UnitType, defender: UID, attacker: UID) -> UID? {
		units[defender].position.n8.firstMap { hx in
			units[hx].flatMap { i, u in
				u.country.team == units[defender].country.team
				&& u.stats.unitType == request
				? i : nil
			}
		}
	}

	mutating func fire(src: UID, dst: UID, defBonus: Int) {
		let atk = Int(units[src].stats.atk(units[dst].stats) + units[src].stats.stars)
		let def = Int(units[dst].stats.def(units[src].stats) + units[dst].stats.stars) + defBonus

		let dif = atk - def
		let t1 = max(1, 7 - dif)
		let t2 = t1 + 4
		let t3 = t2 + 6
		let t4 = t3 + 8
		let rounds = units[src].stats.hp >> 2 + 1

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds.map { d in
			d > t4 ? 4 :
			d > t3 ? 3 :
			d > t2 ? 2 :
			d > t1 ? 1 :
			0 as UInt8
		}
		let dmg: UInt8 = dmgs.reduce(into: 0, +=)

		let srcStr = "\(units[src].country) \(units[src].stats.unitType)"
		let dstStr = "\(units[dst].country) \(units[dst].stats.unitType)"
		let dmgLine = "ds: \(ds) ts: \([t1, t2, t3, t4]) dmg: \(dmgs)"
		print("fire \(srcStr) -> \(dstStr)\natk: \(atk) def: \(def)\n\(dmgLine)")

		let hpLeft = units[dst].stats.hp.decrement(by: dmg)
		units[dst].stats.ent.decrement()

		units[src].stats.ammo.decrement()
		units[src].stats.exp.increment(by: hpLeft != 0 ? dmg : dmg * 2)

		camera = units[dst].position
		events.add(.attack(src, dst, units[dst], dmg))
	}

	mutating func attack(src: UID, dst: UID) {
		guard units[src].country == country,
			  units[src].country.team != units[dst].country.team,
			  units[src].canAttack, units[src].canHit(unit: units[dst])
		else { return }

		let srcIni = UInt8(d20()) + units[src].stats.ini * 2 + 15
		let dstIni = UInt8(d20()) + units[dst].stats.ini * 2 + units[dst].stats.ent * 2
		print("ini: \(srcIni) vs \(dstIni)")

		if units[src].stats.targetType != .air, units[src].stats.unitType != .art,
			let art = support(request: .art, defender: dst, attacker: src) {
			fire(src: art, dst: src, defBonus: 0)
		}
		if units[src].stats.targetType == .air,
		   let aa = support(request: .aa, defender: dst, attacker: src) {
			fire(src: aa, dst: src, defBonus: 0)
		}
		if srcIni > dstIni, units[src].alive {
			let defBonus = Int(units[dst].stats.ent) + map[units[dst].position].defBonus
			fire(src: src, dst: dst, defBonus: defBonus)
			units[src].stats.ap.decrement()
		}
		if units[dst].alive, units[src].alive,
		   units[dst].canHit(unit: units[src]),
		   units[src].stats.unitType != .art {

			let defBonus = switch units[src].stats.targetType {
			case .light where units[dst].stats.targetType != .air: -Int(map[units[dst].position].defBonus)
			case .heavy where units[dst].stats.targetType != .air: -Int(map[units[dst].position].defBonus * 2)
			default: 0
			}
			fire(src: dst, dst: src, defBonus: defBonus)
		}
		if srcIni <= dstIni, units[src].alive {
			let defBonus = Int(units[dst].stats.ent) + map[units[dst].position].defBonus
			fire(src: src, dst: dst, defBonus: defBonus)
			units[src].stats.ap.decrement()
		}

		selectUnit(units[src].alive && units[src].hasActions ? src : .none)
	}
}
