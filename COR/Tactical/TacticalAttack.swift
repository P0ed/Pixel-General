extension TacticalSim {

	mutating func attack(src: UID, dst: UID, surprise: Bool = false, into events: inout [TacticalEvent]) {
		let (si, di) = (src.index, dst.index)
		let (su, du) = (units[si], units[di])

		guard su.country == country, su.country.team != du.country.team,
			  su.ammo > 0, unitCanHit(src, dst), su.canAttack || surprise
		else { return }

		let (sp, dp) = (position[si], position[di])
		let (st, dt) = (map[sp], map[dp])
		let ranged = su.isArt && !surprise

		let ruggedDefence: Bool = ranged ? false : (
			UInt8(d20()) + su.ini * 2 + su.lvl
		) < (
			du.ent * 2 + du.ini * 2 + du.lvl + (surprise ? 10 : 0)
		)
		if ruggedDefence {
			events.append(.ruggedDefence(dp))
		}

		let srcDef: Int8 = (ranged ? Int8(su.entDef) + st.def(su.type) : dt.closeCombat(su.type))
			+ (ruggedDefence ? -3 : 0)
			+ (du.ammo == 0 ? 5 : 0)
		let dstDef: Int8 = defenderMod(defender: dst, attacker: src, ranged: ranged)
			+ (ruggedDefence ? -3 : 0)

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
		if units[di].alive, units[si].alive, unitCanHit(dst, src), !ranged || du.isArt {
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

	mutating func fire(src: UID, dst: UID, defMod: Int8, into events: inout [TacticalEvent]) {
		var (source, destination) = (units[src], units[dst])
		let (atk, def) = combatStats(src: src, dst: dst, defMod: defMod)
		let dmg = Duel(
			atk: atk,
			def: def,
			hp: source.hp,
			crit: source[.crit],
			evasion: destination[.evasion]
		).resolve(&d20)

		source.ammo.decrement()
		destination.hp.decrement(by: dmg)

		let cargoId = cargo[dst]
		if cargoId != .none {
			units[cargoId].hp.decrement(by: dmg)
			if !destination.alive {
				units[cargoId].hp = 0x0
			}
			if !units[cargoId].alive {
				cargo[dst] = .none
				cargo[cargoId] = .none
				events.append(.update(cargoId))
			}
		}
		source.exp.increment(by: UInt16(dmg) * destination.cost / (destination.alive ? 32 : 24))
		if !destination.alive {
			unitsMap[position[dst]] = .none
			source.kills.increment(by: 1)
			source.promote(using: &d20)
			self[source.country].prestige.increment(by: destination.cost / 16)
		}
		units[src] = source
		units[dst] = destination
		events.append(.fire(src, dst, dmg, destination.hp))
	}

	/// The attacker/defender numbers that feed the duel: base `atk`/`def` plus the
	/// leadership/recon/radar auras, with the caller's `defMod` folded into `def`.
	/// Shared by `fire` (live) and `estimateDamage` (prediction) so the aura and
	/// base-stat assembly has a single definition.
	func combatStats(src: UID, dst: UID, defMod: Int8) -> (atk: Int8, def: Int8) {
		let (source, destination) = (units[src], units[dst])
		let aLR: Int8 = aura(.leadership, country: source.country, at: position[src]) ? 1 : 0
		let aRC: Int8 = aura(.recon, country: source.country, at: position[src]) ? 1 : 0
		let dLR: Int8 = aura(.leadership, country: destination.country, at: position[dst]) ? 1 : 0
		let dRC: Int8 = aura(.recon, country: destination.country, at: position[dst]) ? 1 : 0
		let radar: Int8 = destination.isAir && aura(.radar, country: source.country, at: position[src]) ? 2 : 0
		let atk = Int8(source.atk(destination)) + aRC + aLR + radar
		let def = Int8(destination.def(source)) + defMod + dRC + dLR
		return (atk, def)
	}

	/// The defender's terrain/entrenchment modifier for a shot from `attacker`:
	/// entrench + terrain def + (close-combat unless ranged) + mountaineer, minus
	/// the attacker's manhattan/diagonal reach and encirclement. This is the
	/// deterministic part of `attack`'s `dstDef`.
	func defenderMod(defender dst: UID, attacker src: UID, ranged: Bool) -> Int8 {
		let (su, du) = (units[src], units[dst])
		let (sp, dp) = (position[src], position[dst])
		let dxy = dp - sp
		let dt = map[dp]

		let mountaineer: Int8 = dt.isHighground
			? (du[.mountaineer] ? 2 : 0) - (su[.mountaineer] ? 1 : 0) : 0
		let mhtn: Int8 = su[.mhtn] && (dxy.x == 0 || dxy.y == 0) ? 1 : 0
		let diag: Int8 = su[.diag] && (abs(dxy.x) == abs(dxy.y)) ? 1 : 0

		return Int8(du.entDef) + dt.def(du.type) + (ranged ? 0 : dt.closeCombat(du.type))
			+ mountaineer
			- mhtn - diag
			- encirclement(id: dst)
	}

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
				u.country.team == units[defender].country.team && u.isArt && u.ammo > 0
				? unitsMap[hx] : nil
			}
		}
	}

	func aaSupport(defender: UID, attacker: UID) -> UID? {
		position[defender].n8.firstMap { hx in
			unitAt(hx).flatMap { u in
				u.country.team == units[defender].country.team && u.isAA && u.ammo > 0
				? unitsMap[hx] : nil
			}
		}
	}

	private func aura(_ skills: Skills, country: Country, at xy: XY) -> Bool {
		(unitAt(xy)?[skills] ?? false) || neighbors(at: xy).contains {
			units[$0].country == country && units[$0][skills]
		}
	}

	private func aura(_ traits: Traits, country: Country, at xy: XY) -> Bool {
		(unitAt(xy)?[traits] ?? false) || neighbors(at: xy).contains {
			units[$0].country == country && units[$0][traits]
		}
	}

	private func encirclement(id: UID) -> Int8 {
		let team = units[id].country.team
		let enemies = position[id.index].n4.reduce(into: 0 as Int8) { r, xy in
			r += (unitAt(xy).map { u in u.country.team != team ? 1 : 0 } ?? 0)
		}
		return max(0, enemies - 1)
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
		let defMod = defenderMod(defender: defender, attacker: attacker, ranged: a.isArt)
		let (atk, def) = combatStats(src: attacker, dst: defender, defMod: defMod)
		return Duel(
			atk: atk,
			def: def,
			hp: a.hp,
			crit: a[.crit],
			evasion: d[.evasion]
		).expected()
	}
}
