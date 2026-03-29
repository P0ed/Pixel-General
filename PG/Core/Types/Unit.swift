typealias UID = Int

struct Unit: Hashable {
	var country: Country
	var position: XY = .zero
	var hp: UInt8 = 0xF
	var bits: UInt8 = 0
	var ammo: UInt8 = 0
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

	static var empty: Self { .init(country: .swe) }

	mutating func combine(_ other: Self) {
		hp |= other.hp
		bits |= other.bits
		ammo = max(ammo, other.ammo)
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

	static var art: Self { .init(.art) }
	static var aa: Self { .init(.aa) }
	static var supply: Self { .init(.supply) }
	static var elite: Self { .init(.elite) }
	static var transport: Self { .init(.transport) }
	static var radar: Self { .init(.radar) }
	static var fast: Self { .init(.fast) }
	static var range: Self { .init(.range) }
	static var aux: Self { .init(.aux) }
}

extension Traits {
	init(_ trait: Trait) { rawValue = 1 << trait.rawValue }
}

enum Trait: UInt8 {
	case art, aa, supply, elite, transport, radar, fast, range, aux
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

	subscript(_ trait: Trait) -> Bool {
		get { traits.contains(.init(trait)) }
		set { traits.insert(.init(trait)) }
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
}

enum UnitType: UInt8, Hashable {
	case soft, softWheel, lightWheel, lightTrack, heavyTrack, heli, jet
}

extension Unit: DeadOrAlive {
	var alive: Bool { hp > 0 }
}

extension Unit {
	var ap: UInt8 {
		get { bits & 0b1111 }
		set { bits = (bits & 0b1111 << 4) | newValue & 0b1111 }
	}
	var ent: UInt8 {
		get { bits >> 4 }
		set { bits = (newValue & 0b1111) << 4 | bits & 0b1111 }
	}
	var untouched: Bool { ap == 0b11 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { ap & 0b01 > 0 }
	var canAttack: Bool { ap & 0b10 > 0 && ammo > 0 }
	var noRetaliation: Bool { self[.art] }

	func canHit(unit: Unit) -> Bool {
		position.distance(to: unit.position) <= rng * 2 + 1
		&& atk(unit) > 0
		&& (isAir ? ammo > 0 : true)
	}

	var cost: UInt16 {
		expCost + typeCost + traitCost + sum * 2
	}

	mutating func healLoosingXP(_ amount: UInt8) {
		let dhp = hp.increment(
			by: amount,
			cap: 0xF
		)
		exp.decrement(by: dhp * 1 << (stars > 0 ? stars - 1 : stars))
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
		firstMap { i, u in u.position == xy ? (i, u) : nil }
	}
}
