typealias UID = Int8

struct Unit: Hashable {
	var country: Country
	var hp: UInt8 = 0
	var mp: UInt8 = 0
	var ap: UInt8 = 0
	var ammo: UInt8 = 0
	var ent: UInt8 = 0
	var exp: UInt8 = 0
	var type: UnitType = .soft
	var ini: UInt8 = 0
	var softAtk: UInt8 = 0
	var hardAtk: UInt8 = 0
	var airAtk: UInt8 = 0
	var groundDef: UInt8 = 0
	var airDef: UInt8 = 0
	var traits: Traits = []
}

extension Unit: Monoid {

	static var empty: Self { .init(country: .default) }

	mutating func combine(_ other: Self) {
		hp |= other.hp
		mp |= other.mp
		ap |= other.ap
		ammo = max(ammo, other.ammo)
		ent |= other.ent
		exp |= other.exp
		type = type == .soft ? other.type : type
		ini |= other.ini
		softAtk |= other.softAtk
		hardAtk |= other.hardAtk
		airAtk |= other.airAtk
		groundDef |= other.groundDef
		airDef |= other.airDef
		traits.rawValue |= other.traits.rawValue
	}
}

struct Traits: OptionSet, Hashable {
	var rawValue: UInt16

	static var art: Self { .init(rawValue: 1 << 0) }
	static var aa: Self { .init(rawValue: 1 << 1) }
	static var supply: Self { .init(rawValue: 1 << 2) }
	static var elite: Self { .init(rawValue: 1 << 3) }
	static var transport: Self { .init(rawValue: 1 << 4) }
	static var radar: Self { .init(rawValue: 1 << 5) }
	static var fast: Self { .init(rawValue: 1 << 6) }
	static var range: Self { .init(rawValue: 1 << 7) }
	static var aux: Self { .init(rawValue: 1 << 8) }
	static var cargo: Self { .init(rawValue: 1 << 9) }
	static var reserved1: Self { .init(rawValue: 1 << 10) }
	static var reserved2: Self { .init(rawValue: 1 << 11) }
	static var mountaineer: Self { .init(rawValue: 1 << 12) }
	static var bigGuns: Self { .init(rawValue: 1 << 13) }
	static var crit: Self { .init(rawValue: 1 << 14) }
	static var evasion: Self { .init(rawValue: 1 << 15) }
}

extension Unit {

	var isAir: Bool {
		switch type {
		case .heli, .jet: true
		default: false
		}
	}

	var spot: UInt8 {
		self[.radar] ? 3 : 2
	}

	var maxHP: UInt8 { 0xF }
	var maxAP: UInt8 { 1 }
	var maxMP: UInt8 { isAir ? 2 : 1 }

	var maxAmmo: UInt8 {
		guard softAtk > 0 || hardAtk > 0 || airAtk > 0 else { return 0 }
		return switch type {
		case .jet: self[.range] ? 2 : 3
		case .heli: 3
		case .soft where self[.art]: self[.range] ? 6 : 7
		case .soft where self[.aa]: self[.range] ? 5 : 7
		case _ where self[.art]: self[.range] ? 5 : 6
		case _ where self[.aa]: self[.range] ? 4 : 6
		default: 7
		}
	}

	var rng: UInt8 {
		if self[.supply] {
			0
		} else if self[.art] {
			self[.range] ? 3 : 2
		} else if self[.aa] {
			self[.range] ? (isAir ? 2 : 3) : 1
		} else {
			1
		}
	}

	var mov: UInt8 {
		switch type {
		case .soft: (self[.art] || self[.aa] ? 1 : 3) + (self[.fast] ? 1 : 0)
		case .softWheel, .lightWheel: 8 + (self[.fast] ? 1 : 0) - (self[.art] ? 1 : 0)
		case .lightTrack: 7 + (self[.fast] ? 1 : 0) - (self[.art] ? 1 : 0)
		case .heavyTrack: 6 + (self[.fast] ? 1 : 0) - (self[.art] ? 1 : 0)
		case .heli: 11 + (self[.fast] ? 2 : 0)
		case .jet: 13 + (self[.fast] ? 2 : 0)
		}
	}

	subscript(_ ts: Traits) -> Bool {
		get { !traits.intersection(ts).isEmpty }
		set { traits.formUnion(ts) }
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

	func defMod(vs enemy: Unit, in terrain: Terrain) -> Int {
		let closeCombat = !enemy.isAir && !enemy.noRetaliation && enemy.rng == 1
		? terrain.closeCombatPenalty(type) / 2 : 0

		let mountaineer = terrain.isHighground
		? (self[.mountaineer] ? 2 : 0) - (enemy[.mountaineer] ? 1 : 0) : 0

		let bigGuns = enemy[.bigGuns] ? -1 : 0

		return Int(ent) + terrain.def + closeCombat + mountaineer + bigGuns
	}
}

enum UnitType: UInt8, Hashable {
	case soft, softWheel, lightWheel, lightTrack, heavyTrack, heli, jet
}

extension Unit: DeadOrAlive {
	var alive: Bool { hp > 0 }
}

extension Unit {

	var untouched: Bool { ap & 0b11 == 0b11 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { ap & 0b01 == 0b01 }
	var canAttack: Bool { ap & 0b10 == 0b10 && ammo > 0 }
	var noRetaliation: Bool { self[.art] }

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
			cap: 0xF
		)
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
		case .heli: 220
		case .jet: 330
		}
	}

	private var sum: UInt16 {
		UInt16(softAtk + hardAtk + airAtk + groundDef + airDef + ini + mov + rng)
	}
}

extension Speicher where Element == Unit {

	subscript(_ xy: XY) -> (UID, Unit)? {
		let i = xy.x + xy.y * 4
		let u = self[i]
		return u.alive ? (i.uid, u) : nil
	}
}

extension UID { var index: Int { Int(self) } }
extension Int { var uid: UID { UID(self) } }
