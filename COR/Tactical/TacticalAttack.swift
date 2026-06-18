extension TacticalSim {

	func unitCanHit(_ src: UID, _ dst: UID) -> Bool {
		let su = units[src]
		let du = units[dst]
		let sp = position[src]
		let dp = position[dst]
		return sp.stepDistance(to: dp) <= su.rng * 2 + 1
			&& su.atk(du) > 0
			&& (su.isAir ? su.ammo > 0 : true)
	}

	func artSupport(defender: UID, attacker: UID) -> UID? {
		position[defender].n8.firstMap { hx in
			unitAt(hx).flatMap { u in
				u.country.team == units[defender].country.team && u.isArt
				? unitsMap[hx] : nil
			}
		}
	}

	func aaSupport(defender: UID, attacker: UID) -> UID? {
		position[defender].n8.firstMap { hx in
			unitAt(hx).flatMap { u in
				u.country.team == units[defender].country.team && u.isAA
				? unitsMap[hx] : nil
			}
		}
	}

	func aura(_ skills: Skills, country: Country, at xy: XY) -> Bool {
		(unitAt(xy)?[skills] ?? false) || neighbors(at: xy).contains {
			units[$0].country == country && units[$0][skills]
		}
	}

	mutating func fire(src: UID, dst: UID, defMod: Int8, into events: inout [TacticalEvent]) {
		var (source, destination) = (units[src], units[dst])
		let aLR: Int8 = aura(.leadership, country: source.country, at: position[src]) ? 1 : 0
		let aRC: Int8 = aura(.recon, country: source.country, at: position[src]) ? 1 : 0
		let dLR: Int8 = aura(.leadership, country: destination.country, at: position[dst]) ? 1 : 0
		let dRC: Int8 = aura(.recon, country: destination.country, at: position[dst]) ? 1 : 0
		let atk = Int8(source.atk(destination)) + aRC + aLR
		let def = Int8(destination.def(source)) + defMod + dRC + dLR

		let dif = atk - def
		let t1 = max(0, 9 - dif)
		let t2 = max(1, 15 - dif)
		let t3 = max(2, 21 - dif)
		let t4 = max(3, 27 - dif)
		let iniRound = source.ini + source.lvl / 2 > d20(.max, 2)
		let rounds: UInt8 = (source.hp + 2) / 3 + (iniRound ? 1 : 0)
		let crit = source[.crit]
		let evasion = destination[.evasion]

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds.map { d in
			var dmg: UInt8 = d > t4 ? 4 : d > t3 ? 3 : d > t2 ? 2 : d > t1 ? 1 : 0
			if crit, d20() > 16 { dmg *= 2 }
			if evasion, d20() > 16 { dmg = 0 }
			return dmg
		}
		let dmg: UInt8 = dmgs.reduce(into: 0, +=)

		source.ammo.decrement()
		destination.hp.decrement(by: dmg)

		let cargoId = cargo[dst]
		if cargoId != .none {
			units[cargoId].hp.decrement(by: dmg)
		}
		if !destination.alive {
			unitsMap[position[dst]] = .none
			if cargoId != .none {
				units[cargoId].hp = 0x0
			}
		}
		if cargoId != .none, !units[cargoId].alive {
			cargo[dst] = .none
			cargo[cargoId] = .none
			events.append(.update(cargoId))
		}

		source.exp.increment(by: UInt16(dmg) * destination.cost / (destination.alive ? 32 : 24))
		if !destination.alive {
			source.kills.increment(by: 1)
			source.promote(using: &d20)
			self[source.country].prestige.increment(by: destination.cost / 16)
		}
		units[src] = source
		units[dst] = destination
		events.append(.fire(src, dst, dmg, destination.hp))
	}

	private func encirclement(id: UID) -> Int8 {
		let team = units[id].country.team
		let enemies = position[id.index].n4.reduce(into: 0 as Int8) { r, xy in
			r += (unitAt(xy).map { u in u.country.team != team ? 1 : 0 } ?? 0)
		}
		return max(0, enemies - 1)
	}

	mutating func attack(src: UID, dst: UID, surprise: Bool = false, into events: inout [TacticalEvent]) {
		let (si, di) = (src.index, dst.index)
		let (su, du) = (units[si], units[di])

		guard su.country == country, su.country.team != du.country.team,
			  su.ammo > 0, unitCanHit(src, dst), su.canAttack || surprise
		else { return }

		let (sp, dp) = (position[si], position[di])
		let dxy = dp - sp
		let dt = map[dp]

		let ruggedDefence: Bool = !surprise && su.isArt ? false : (
			d20() + Int(su.ini + su.lvl) * 2
		) < (
			Int(du.ent + du.ini + du.lvl) * 2 + (surprise ? 10 : 0)
		)
		if ruggedDefence {
			events.append(.ruggedDefence(dp))
		}

		let mountaineer: Int8 = dt.isHighground
			? (du[.mountaineer] ? 2 : 0) - (su[.mountaineer] ? 1 : 0) : 0
		let mhtn: Int8 = su[.mhtn] && (dxy.x == 0 || dxy.y == 0) ? -1 : 0
		let diag: Int8 = su[.diag] && (abs(dxy.x) == abs(dxy.y)) ? -1 : 0

		let srcDef: Int8 = (su.isArt ? 0 : dt.closeCombat(su.type))
			+ (ruggedDefence ? -3 : 0)
			+ (du.ammo == 0 ? 5 : 0)
		let dstDef: Int8 = Int8(du.entDef) + dt.def(du.type)
			+ mountaineer
			+ mhtn + diag
			- encirclement(id: dst)

		units[si].ap.decrement()

		if !su.isAir, !du.isAir, !su.isArt, let art = artSupport(defender: dst, attacker: src) {
			fire(src: art, dst: src, defMod: 0, into: &events)
		}
		if su.isAir, !du.isAA, let aa = aaSupport(defender: dst, attacker: src) {
			fire(src: aa, dst: src, defMod: 0, into: &events)
		}
		if !ruggedDefence, units[si].alive {
			fire(src: src, dst: dst, defMod: dstDef, into: &events)
			units[di].ent.decrement(by: su.entDamage)
		}
		if units[di].alive, units[si].alive, unitCanHit(dst, src), !su.isArt || du.isArt || surprise {
			fire(src: dst, dst: src, defMod: srcDef, into: &events)
		}
		if ruggedDefence, units[si].alive {
			fire(src: src, dst: dst, defMod: dstDef, into: &events)
			units[di].ent.decrement(by: su.entDamage)
		}
		if units[di].alive, units[di].hp * 2 + units[di].ini + UInt8(d20()) < 20 {
			retreat(unit: dst, from: position[si], into: &events)
		}
	}

	private mutating func retreat(unit id: UID, from xy: XY, into events: inout [TacticalEvent]) {
		let p = position[id]
		let pos = moves(for: id).ordered.min(by: (p + p - xy).manhattanComparator)
		guard let pos, unitAt(pos) == nil else { return }

		unitsMap[position[id]] = .none
		unitsMap[pos] = id
		position[id] = pos
		if cargo[id] != .none {
			position[cargo[id].index] = pos
		}
		units[id].ent = 0
		var path = CArray<16, XY>(head: p, tail: .zero)
		path.add(pos)
		events.append(.move(id, Path(count: path.count, path: path.mem)))
		if cargo[id.index] != .none {
			events.append(.move(cargo[id], Path(count: path.count, path: path.mem)))
		}
	}

	func estimateDamage(attacker: UID, defender: UID) -> UInt8 {
		let (a, d) = (units[attacker], units[defender])
		let atk = Int8(a.atk(d))
		let def = Int8(d.def(a) + d.entDef)

		let rounds = Int(a.hp + 3) / 3
		let base = max(0, 127 + Int(atk - def) * 15)
		let crit = a[.crit] ? 120 : 100
		let evasion = d[.evasion] ? 80 : 100

		return UInt8(clamping: rounds * base * crit * evasion / 1_00_00_00)
	}
}
