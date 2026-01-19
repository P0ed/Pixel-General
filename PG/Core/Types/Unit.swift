struct Unit: Hashable {
	var country: Country
	var position: XY
	var stats: Stats
}

typealias UID = Int

struct Stats: RawRepresentable, Hashable {
	var rawValue: UInt64
}

extension Stats: Monoid {
	static var empty: Self { .init(rawValue: 0) }
	mutating func combine(_ other: Self) { rawValue |= other.rawValue }
}

extension Stats {

	private static func mask(width: UInt8, offset: UInt8) -> RawValue {
		((1 << width) - 1) << offset
	}
	private func get(width: UInt8, offset: UInt8) -> UInt8 {
		let mask = Self.mask(width: width, offset: offset)
		return UInt8((rawValue & mask) >> offset)
	}
	private mutating func set(_ value: UInt8, width: UInt8, offset: UInt8) {
		let mask = Self.mask(width: width, offset: offset)
		rawValue &= ~mask
		rawValue |= RawValue(value) << offset & mask
	}

	var hp: UInt8 {
		get { get(width: 4, offset: 0) }
		set { set(newValue, width: 4, offset: 0) }
	}
	var mp: UInt8 {
		get { get(width: 1, offset: 4) }
		set { set(newValue, width: 1, offset: 4) }
	}
	var ap: UInt8 {
		get { get(width: 1, offset: 5) }
		set { set(newValue, width: 1, offset: 5) }
	}
	var ammo: UInt8 {
		get { get(width: 3, offset: 6) }
		set { set(newValue, width: 3, offset: 6) }
	}
	var mtm: UInt8 {
		get { get(width: 2, offset: 9) }
		set { set(newValue, width: 2, offset: 9) }
	}
	var ent: UInt8 {
		get { get(width: 3, offset: 11) }
		set { set(newValue, width: 3, offset: 11) }
	}
	var exp: UInt8 {
		get { get(width: 8, offset: 14) }
		set { set(newValue, width: 8, offset: 14) }
	}
	var type: UnitType {
		get { UnitType(rawValue: get(width: 3, offset: 22)) ?? .soft }
		set { set(newValue.rawValue, width: 3, offset: 22) }
	}
	var rng: UInt8 {
		get { get(width: 3, offset: 25) }
		set { set(newValue, width: 3, offset: 25) }
	}
	var mov: UInt8 {
		get { get(width: 4, offset: 28) }
		set { set(newValue, width: 4, offset: 28) }
	}
	var ini: UInt8 {
		get { get(width: 4, offset: 32) }
		set { set(newValue, width: 4, offset: 32) }
	}
	var softAtk: UInt8 {
		get { get(width: 4, offset: 36) }
		set { set(newValue, width: 4, offset: 36) }
	}
	var hardAtk: UInt8 {
		get { get(width: 4, offset: 40) }
		set { set(newValue, width: 4, offset: 40) }
	}
	var airAtk: UInt8 {
		get { get(width: 4, offset: 44) }
		set { set(newValue, width: 4, offset: 44) }
	}
	var groundDef: UInt8 {
		get { get(width: 4, offset: 48) }
		set { set(newValue, width: 4, offset: 48) }
	}
	var airDef: UInt8 {
		get { get(width: 4, offset: 52) }
		set { set(newValue, width: 4, offset: 52) }
	}
	subscript(_ trait: Trait) -> Bool {
		get { get(width: 1, offset: 56 + trait.rawValue) == 1 }
		set { set(newValue ? 1 : 0, width: 1, offset: 56 + trait.rawValue) }
	}
}

enum Trait: UInt8 {
	case art, aa, supply, hardcore, transport, xf, xg, xh
}

extension Stats {

	var stars: UInt8 {
		modifying(4) { stars in stars.decrement(by: UInt8(exp.leadingZeroBitCount)) }
	}

	var isAir: Bool { type == .air }

	func atk(_ dst: Stats) -> UInt8 {
		switch dst.type {
		case .soft, .softWheel: softAtk
		case .lightWheel, .lightTrack: (2 * softAtk + hardAtk) / 3
		case .mediumWheel, .mediumTrack: (softAtk + 2 * hardAtk) / 3
		case .heavyTrack: hardAtk
		case .air: airAtk
		}
	}

	func def(_ src: Stats) -> UInt8 {
		src.isAir ? airDef : groundDef
	}
}

enum UnitType: UInt8, Hashable {
	case soft, softWheel, lightWheel, mediumWheel, lightTrack, mediumTrack, heavyTrack, air
}

extension Unit: DeadOrAlive {

	static var none: Unit {
		.init(country: .zero, position: .zero, stats: .empty)
	}

	var alive: Bool { stats.hp > 0 }
}

extension Unit {

	var untouched: Bool { stats.mp == 1 && stats.ap == 1 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { stats.mp > 0 }
	var canAttack: Bool { stats.ap > 0 && stats.ammo > 0 }

	func canHit(unit: Unit) -> Bool {
		position.distance(to: unit.position) <= stats.rng * 2 + 1
		&& stats.atk(unit.stats) > 0
	}

	var cost: UInt16 { stats.cost }
}

extension Stats {

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
		case .soft: 40
		case .softWheel: 80
		case .lightWheel: 110
		case .mediumWheel: 140
		case .lightTrack: 120
		case .mediumTrack: 150
		case .heavyTrack: 180
		case .air: 220
		}
	}

	private var sum: UInt16 {
		UInt16(softAtk + hardAtk + airAtk + groundDef + airDef + ini + mov + rng)
	}
}
