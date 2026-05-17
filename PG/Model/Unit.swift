typealias UID = Int8

struct Unit: Equatable {
	var country: Country = .default
	var hp: UInt8 = 0
	var mp: UInt8 = 0
	var ap: UInt8 = 0
	var ammo: UInt8 = 0
	var ent: UInt8 = 0
	var exp: UInt8 = 0
	var type: UnitType = .soft
	var mov: UInt8 = 0
	var rng: UInt8 = 0
	var ini: UInt8 = 0
	var softAtk: UInt8 = 0
	var hardAtk: UInt8 = 0
	var airAtk: UInt8 = 0
	var groundDef: UInt8 = 0
	var airDef: UInt8 = 0
	var traits: Traits = []
}

struct Traits: OptionSet, Equatable {
	var rawValue: UInt16

	static var aux: Self { .init(rawValue: 1 << 0) }
	static var art: Self { .init(rawValue: 1 << 1) }
	static var aa: Self { .init(rawValue: 1 << 2) }
	static var x_x: Self { .init(rawValue: 1 << 3) }
	static var supply: Self { .init(rawValue: 1 << 4) }
	static var elite: Self { .init(rawValue: 1 << 5) }
	static var transport: Self { .init(rawValue: 1 << 6) }
	static var radar: Self { .init(rawValue: 1 << 7) }
	static var leadership: Self { .init(rawValue: 1 << 8) }
	static var recon: Self { .init(rawValue: 1 << 9) }
	static var crit: Self { .init(rawValue: 1 << 10) }
	static var evasion: Self { .init(rawValue: 1 << 11) }
	static var regen: Self { .init(rawValue: 1 << 12) }
	static var mountaineer: Self { .init(rawValue: 1 << 13) }
	static var mhtn: Self { .init(rawValue: 1 << 14) }
	static var diag: Self { .init(rawValue: 1 << 15) }
}

extension Unit {

	var isAir: Bool { type == .heli || type == .jet }
	var untouched: Bool { ap == maxAP && mp == maxMP }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { mp > 0 }
	var canAttack: Bool { ap > 0 && ammo > 0 }
	var spot: UInt8 { self[.radar] ? 3 : 2 }

	var maxHP: UInt8 { 0xF }
	var maxAP: UInt8 { 1 }
	var maxMP: UInt8 { isAir ? 2 : 1 }

	var maxAmmo: UInt8 {
		guard softAtk > 0 || hardAtk > 0 || airAtk > 0 else { return 0 }

		return switch type {
		case .jet where rng > 1: 2
		case .jet: 3
		case .heli: 3
		case .soft where self[.art]: 6
		case .soft where self[.aa] && rng > 1: 5
		case .soft where self[.aa]: 7
		case _ where self[.art]: 5
		case _ where self[.aa] && rng > 1: 4
		case _ where self[.aa]: 6
		default: 7
		}
	}

	subscript(_ ts: Traits) -> Bool {
		get { !traits.intersection(ts).isEmpty }
		set { newValue ? traits.formUnion(ts) : traits.subtract(ts) }
	}

	var stars: UInt8 {
		modifying(4) { stars in stars.decrement(by: UInt8(exp.leadingZeroBitCount)) }
	}

	func atk(_ dst: Unit) -> UInt8 {
		switch dst.type {
		case .soft, .softWheel: softAtk
		case .lightWheel, .lightTrack, .heavyTrack: hardAtk
		case .heli, .jet: airAtk
		}
	}

	func def(_ src: Unit) -> UInt8 {
		src.isAir ? airDef : groundDef
	}

	func defMod(vs enemy: Unit, in terrain: Terrain, dxy: XY) -> Int8 {
		let closeCombat: Int8 = !enemy.isAir && !enemy[.art] && enemy.rng == 1
		? terrain.closeCombatPenalty(type) / 2 : 0

		let mountaineer: Int8 = terrain.isHighground
		? (self[.mountaineer] ? 2 : 0) - (enemy[.mountaineer] ? 1 : 0) : 0

		let mhtn: Int8 = enemy[.mhtn] && (dxy.x == 0 || dxy.y == 0) ? -1 : 0
		let diag: Int8 = enemy[.diag] && (abs(dxy.x) == abs(dxy.y)) ? -1 : 0

		return Int8(ent) + terrain.def + closeCombat + mountaineer + mhtn + diag
	}

	var cost: UInt16 {
		(expCost + typeCost + traitCost + sum * 2) / (self[.aux] ? 2 : 1)
	}

	mutating func healLoosingXP(_ amount: UInt8) {
		exp.decrement(by: heal(amount) * 1 << (stars > 0 ? stars - 1 : stars))
	}

	@discardableResult
	mutating func heal(_ amount: UInt8) -> UInt8 {
		hp.increment(
			by: amount,
			cap: maxHP
		)
	}

	mutating func promote(using d20: inout D20) {
		let skills = [8 of Traits].init { i in Traits(rawValue: 1 << (i + 8)) }
		let left = .init { i in self[skills[i]] ? nil : skills[i] } as [8 of Traits?]
		let cnt = left.reduce(into: 0, { r, t in r += t == nil ? 1 : 0 })

		if stars * 2 > UInt8(cnt),
		   d20(.min(3)) > 6 + cnt,
		   let rnd = left.compactMap(id).randomElement(using: &d20)
		{
			traits.insert(rnd)
		}
	}

	private var expCost: UInt16 {
		UInt16(stars) * (typeCost + traitCost + sum) / 6
	}

	private var traitCost: UInt16 {
		UInt16(traits.rawValue.nonzeroBitCount) * 20
	}

	private var typeCost: UInt16 {
		switch type {
		case .soft: 33
		case .softWheel: 47
		case .lightWheel: 100
		case .lightTrack: 120
		case .heavyTrack: 150
		case .heli: 180
		case .jet: 220
		}
	}

	private var sum: UInt16 {
		UInt16(softAtk + hardAtk + airAtk * 2 + groundDef + airDef + ini + mov + rng * 3)
	}
}

enum UnitType: UInt8, Hashable {
	case soft, softWheel, lightWheel, lightTrack, heavyTrack, heli, jet
}

extension Unit: DeadOrAlive {
	var alive: Bool { hp > 0 }
}

extension InlineArray where Element == Unit, count == 16 {

	subscript(_ xy: XY) -> (UID, Unit)? {
		let i = xy.x + xy.y * 4
		let u = self[i]
		return u.alive ? (i.uid, u) : nil
	}
}

extension UID { var index: Int { Int(self) } }
extension Int { var uid: UID { UID(self) } }
