typealias UID = Int

struct Unit: Hashable {
	var country: Country
	var position: XY = .zero
	var hp: UInt8 = 0
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
	static var empty: Self { .init(country: .swe) }
	mutating func combine(_ other: Self) {
		hp |= other.hp
		ap |= other.ap
		ammo |= other.ammo
		ent |= other.ent
		exp |= other.exp
		type = .init(rawValue: type.rawValue | other.type.rawValue) ?? other.type
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
	var rawValue: UInt8

	static var art: Self { .init(.art) }
	static var aa: Self { .init(.aa) }
	static var supply: Self { .init(.supply) }
	static var hardcore: Self { .init(.hardcore) }
	static var transport: Self { .init(.transport) }
	static var radar: Self { .init(.radar) }
	static var fast: Self { .init(.fast) }
	static var com: Self { .init(.com) }
}

extension Traits {
	init(_ trait: Trait) { rawValue = 1 << trait.rawValue }
}

enum Trait: UInt8 {
	case art, aa, supply, hardcore, transport, radar, fast, com
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

	var rng: UInt8 {
		if self[.supply] {
			0
		} else if self[.art] || self[.aa] {
			isAir ? 2 : 3
		} else {
			1
		}
	}

	var mov: UInt8 {
		switch type {
		case .soft: (self[.art] || self[.aa] ? 1 : 3) + (self[.fast] ? 1 : 0)
		case .softWheel, .lightWheel: 8 + (self[.fast] ? 1 : 0)
		case .lightTrack: 7 + (self[.fast] ? 1 : 0)
		case .heavyTrack: 6 + (self[.fast] ? 1 : 0)
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
		case .lightWheel, .lightTrack: (softAtk + hardAtk * 2) / 3
		case .heavyTrack: hardAtk
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
	var untouched: Bool { ap == 0b11 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { ap & 0b01 > 0 }
	var canAttack: Bool { ap & 0b10 > 0 && ammo > 0 }
	var noRetaliation: Bool { self[.art] }

	func canHit(unit: Unit) -> Bool {
		position.distance(to: unit.position) <= rng * 2 + 1
		&& atk(unit) > 0
	}
}

extension Unit {

	var hasAmmo: Bool { softAtk + hardAtk + airAtk > 0 }

	var cost: UInt16 {
		expCost + typeCost + traitCost + sum * 3 / (isAir ? 1 : 2)
	}

	private var expCost: UInt16 {
		UInt16(stars) * (typeCost + traitCost) >> 2
	}

	private var traitCost: UInt16 {
		(self[.aa] ? 40 + typeCost >> 2 : 0)
		+ (self[.art] ? 40 + typeCost >> 2 : 0)
		+ (self[.hardcore] ? 60 + typeCost >> 1 : 0)
	}

	private var typeCost: UInt16 {
		switch type {
		case .soft: 47
		case .softWheel: 68
		case .lightWheel: 120
		case .lightTrack: 150
		case .heavyTrack: 180
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
