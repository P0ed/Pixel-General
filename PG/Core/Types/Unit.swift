struct Unit: RawRepresentable, Hashable {
	var rawValue: UInt128
}

typealias UID = Int

extension Unit: Monoid {
	static var empty: Self { .init(rawValue: 0) }
	mutating func combine(_ other: Self) { rawValue |= other.rawValue }
}

extension Unit {

	init(country: Country) {
		self = .make { $0.country = country }
	}

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
	var position: XY {
		get {
			XY(
				Int(Int8(bitPattern: get(width: 8, offset: 64))),
				Int(Int8(bitPattern: get(width: 8, offset: 72)))
			)
		}
		set {
			set(UInt8(bitPattern: Int8(clamping: newValue.x)), width: 8, offset: 64)
			set(UInt8(bitPattern: Int8(clamping: newValue.y)), width: 8, offset: 72)
		}
	}
	var country: Country {
		get { .init(rawValue: get(width: 4, offset: 80)) ?? .zero }
		set { set(newValue.rawValue, width: 4, offset: 80) }
	}
}

enum Trait: UInt8 {
	case art, aa, supply, hardcore, transport, xf, xg, xh
}

extension Unit {

	var stars: UInt8 {
		modifying(4) { stars in stars.decrement(by: UInt8(exp.leadingZeroBitCount)) }
	}

	var isAir: Bool { type == .air }

	func atk(_ dst: Unit) -> UInt8 {
		switch dst.type {
		case .soft, .softWheel: softAtk
		case .lightWheel, .lightTrack: (2 * softAtk + hardAtk) / 3
		case .mediumWheel, .mediumTrack: (softAtk + 2 * hardAtk) / 3
		case .heavyTrack: hardAtk
		case .air: airAtk
		}
	}

	func def(_ src: Unit) -> UInt8 {
		src.isAir ? airDef : groundDef
	}
}

enum UnitType: UInt8, Hashable {
	case soft, softWheel, lightWheel, mediumWheel, lightTrack, mediumTrack, heavyTrack, air
}

extension Unit: DeadOrAlive {
	var alive: Bool { hp > 0 }
}

extension Unit {

	static var none: Unit { .empty }

	var untouched: Bool { mp == 1 && ap == 1 }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { mp > 0 }
	var canAttack: Bool { ap > 0 && ammo > 0 }
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

extension Speicher where Element == Unit {

	subscript(_ xy: XY) -> (UID, Unit)? {
		firstMap { i, u in u.position == xy ? (i, u) : nil }
	}
}

extension Speicher where Element == Building {

	subscript(_ xy: XY) -> Building? {
		firstMap { _, b in b.position == xy ? b : nil }
	}
}
