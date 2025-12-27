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
	var atm: UInt8 {
		get { get(width: 2, offset: 9) }
		set { set(newValue, width: 2, offset: 9) }
	}
	var aam: UInt8 {
		get { get(width: 2, offset: 11) }
		set { set(newValue, width: 2, offset: 11) }
	}
	var ent: UInt8 {
		get { get(width: 3, offset: 13) }
		set { set(newValue, width: 3, offset: 13) }
	}
	var exp: UInt8 {
		get { get(width: 8, offset: 16) }
		set { set(newValue, width: 8, offset: 16) }
	}
	var unitType: UnitType {
		get { UnitType(rawValue: get(width: 2, offset: 24)) ?? .fighter }
		set { set(newValue.rawValue, width: 2, offset: 24) }
	}
	var moveType: MoveType {
		get { MoveType(rawValue: get(width: 2, offset: 26)) ?? .leg }
		set { set(newValue.rawValue, width: 2, offset: 26) }
	}
	var targetType: TargetType {
		get { TargetType(rawValue: get(width: 2, offset: 28)) ?? .soft }
		set { set(newValue.rawValue, width: 2, offset: 28) }
	}
	var rng: UInt8 {
		get { get(width: 2, offset: 30) }
		set { set(newValue, width: 2, offset: 30) }
	}
	var mov: UInt8 {
		get { get(width: 4, offset: 32) }
		set { set(newValue, width: 4, offset: 32) }
	}
	var ini: UInt8 {
		get { get(width: 4, offset: 36) }
		set { set(newValue, width: 4, offset: 36) }
	}
	var softAtk: UInt8 {
		get { get(width: 4, offset: 40) }
		set { set(newValue, width: 4, offset: 40) }
	}
	var hardAtk: UInt8 {
		get { get(width: 4, offset: 44) }
		set { set(newValue, width: 4, offset: 44) }
	}
	var airAtk: UInt8 {
		get { get(width: 4, offset: 48) }
		set { set(newValue, width: 4, offset: 48) }
	}
	var groundDef: UInt8 {
		get { get(width: 4, offset: 52) }
		set { set(newValue, width: 4, offset: 52) }
	}
	var airDef: UInt8 {
		get { get(width: 4, offset: 56) }
		set { set(newValue, width: 4, offset: 56) }
	}
}

extension Stats {

	var stars: UInt8 {
		modifying(4) { stars in stars.decrement(by: UInt8(exp.leadingZeroBitCount)) }
	}

	func atk(_ dst: Stats) -> UInt8 {
		switch dst.targetType {
		case .soft: softAtk
		case .light: (softAtk + hardAtk) >> 1
		case .heavy: hardAtk
		case .air: airAtk
		}
	}

	func def(_ src: Stats) -> UInt8 {
		src.targetType == .air ? airDef : groundDef
	}
}

enum UnitType: UInt8, Hashable {
	case fighter, art, aa, support
}

enum TargetType: UInt8, Hashable {
	case soft, light, heavy, air
}

enum MoveType: UInt8, Hashable {
	case leg, wheel, track, air
}

extension Unit: DeadOrAlive {

	static var dead: Unit {
		.init(country: .dnr, position: .zero, stats: .empty)
	}

	var alive: Bool { stats.hp > 0 }
}

extension Unit {

	var untouched: Bool { stats.mp != 0 && stats.ap != 0 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { stats.mp != 0 }
	var canAttack: Bool { stats.ap != 0 && stats.ammo != 0 }

	func canHit(unit: Unit) -> Bool {
		position.distance(to: unit.position) <= stats.rng * 2 + 1
	}

	var cost: UInt16 {
		switch stats.unitType {
		case .fighter: switch stats.moveType {
		case .leg: 80
		case .wheel: 180
		case .track: 240
		case .air: 320
		}
		case .art: 220
		case .aa: 280
		case .support: 60
		}
	}
}
