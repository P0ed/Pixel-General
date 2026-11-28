public struct Unit: Equatable, Sendable {
	public var model: UnitModel = .none
	public var country: Country = .default
	public var hp: UInt8 = 0
	public var mp: UInt8 = 0
	public var ap: UInt8 = 0
	public var ammo: UInt8 = 0
	public var ent: UInt8 = 0
	public var exp: UInt8 = 0
	public var skills: Skills = []
	public var bits: Bits = []
}

public struct Bits: OptionSet, Equatable, Sendable {
	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension Bits {
	static var aux: Self 			{ .init(rawValue: 1 << 0) }
	static var overwatch: Self 		{ .init(rawValue: 1 << 1) }
	static var stun: Self 			{ .init(rawValue: 1 << 2) }
	static var slow: Self 			{ .init(rawValue: 1 << 3) }
}

public struct Skills: OptionSet, Equatable, Sendable {
	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension Skills {
	static var leadership: Self 	{ .init(rawValue: 1 << 0x0) }
	static var recon: Self		 	{ .init(rawValue: 1 << 0x1) }
	static var crit: Self 			{ .init(rawValue: 1 << 0x2) }
	static var evasion: Self 		{ .init(rawValue: 1 << 0x3) }
	static var regen: Self 			{ .init(rawValue: 1 << 0x4) }
	static var mountaineer: Self	{ .init(rawValue: 1 << 0x5) }
	static var mhtn: Self 			{ .init(rawValue: 1 << 0x6) }
	static var diag: Self 			{ .init(rawValue: 1 << 0x7) }
}

public extension Unit {

	static var empty: Self { .init() }

	var stats: UnitStats { UnitStats.table[Int(model.rawValue)] }

	var type: UnitType { stats.type }
	var tier: UInt8 { stats.tier }
	var mov: UInt8 { stats.mov }
	var rng: UInt8 { stats.rng }
	var ini: UInt8 { stats.ini }
	var softAtk: UInt8 { stats.softAtk }
	var hardAtk: UInt8 { stats.hardAtk }
	var airAtk: UInt8 { stats.airAtk }
	var navAtk: UInt8 { stats.navAtk }
	var groundDef: UInt8 { stats.groundDef }
	var airDef: UInt8 { stats.airDef }
	var traits: Traits { stats.traits }

	var isAir: Bool { type.isAir }
	var isNaval: Bool { type.isNaval }
	var isLand: Bool { !type.isAir && !type.isNaval }
	var untouched: Bool { fullAP && fullMP }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { mp > 0 }
	var canAttack: Bool { ap > 0 }

	var spot: UInt8 { self[.optics] ? 3 : 2 }

	var maxHP: UInt8 { 0xF }
	var maxAP: UInt8 { rng == 0 ? 0 : 1 }
	var maxMP: UInt8 { isAir ? 2 : 1 }
	var maxAmmo: UInt8 { stats.ammo }

	var fullHP: Bool { hp == maxHP }
	var fullAP: Bool { ap == maxAP }
	var fullMP: Bool { mp == maxMP }
	var fullAmmo: Bool { ammo == maxAmmo }

	var isAA: Bool { type.isAA }
	var isArt: Bool { type.isArt }

	var isArmor: Bool {
		switch type {
		case .lightWheel, .lightTrack, .heavyTrack: true;
		default: false
		}
	}

	var canAttackAfterMove: Bool {
		switch type {
		case .art, .aa, .wheelAA: false
		default: true
		}
	}

	var transportable: Bool {
		switch type {
		case .inf, .art, .aa: true
		default: false
		}
	}

	var entDef: UInt8 {
		ent / 4
	}

	var entRate: UInt8 {
		let rate: UInt8 = switch type {
		case .supply, .inf: 4 + lvl
		case .art, .aa, .wheelArt, .wheelAA, .lightWheel, .lightTrack: 3 + lvl
		case .heavyTrack, .trackAA, .trackArt: 2 + lvl
		case .heli, .fighter, .cas, .cargo, .destroyer, .cruiser: 0
		}
		return rate * (self[.engineer] ? 2 : 1)
	}

	var entDamage: UInt8 {
		self[.engineer] ? 8 : 4
	}

	subscript(_ bs: Bits) -> Bool {
		get { !bits.intersection(bs).isEmpty }
		set { newValue ? bits.formUnion(bs) : bits.subtract(bs) }
	}

	subscript(_ ts: Traits) -> Bool {
		!traits.intersection(ts).isEmpty
	}

	subscript(_ ss: Skills) -> Bool {
		get { !skills.intersection(ss).isEmpty }
		set { newValue ? skills.formUnion(ss) : skills.subtract(ss) }
	}

	static let maxLvl: UInt8 = 4

	private static func minimumExp(for lvl: UInt8) -> UInt8 {
		lvl == 0 ? 0 : 1 << (3 + lvl)
	}

	var lvl: UInt8 {
		get {
			UInt8(clamping: Int(Self.maxLvl) - exp.leadingZeroBitCount)
		}
		set {
			exp = Self.minimumExp(for: min(newValue, Self.maxLvl))
		}
	}

	var subLvl: UInt8 {
		let lvl = lvl
		guard lvl < Self.maxLvl else { return 0 }
		let start = Self.minimumExp(for: lvl)
		let span = Self.minimumExp(for: lvl + 1) - start
		return UInt8(UInt16(exp - start) * 10 / UInt16(span))
	}

	func atk(_ dst: Unit) -> UInt8 {
		switch dst.type.targetType {
		case .soft:
			softAtk > 0 ? softAtk + lvl : 0
		case .hard:
			hardAtk > 0 ? hardAtk + (isArmor ? lvl : (lvl / 2)) : 0
		case .air:
			airAtk > 0 ? airAtk + (isAA ? lvl : (lvl / 2)) : 0
		case .naval:
			navAtk > 0 ? navAtk + (isNaval ? lvl : (lvl / 2)) : 0
		}
	}

	func def(_ src: Unit) -> UInt8 {
		(src.isAir ? airDef : groundDef) + lvl
	}

	var value: UInt16 {
		(typeValue + traitValue + statsValue) * UInt16(2 + lvl) / 3
	}

	private var typeValue: UInt16 {
		switch type.moveType {
		case .leg: 1
		case .wheel: 22
		case .track: 47
		case .air: 68
		case .naval: 100
		}
	}

	private var traitValue: UInt16 {
		UInt16(traits.rawValue.nonzeroBitCount) * 22
		+ UInt16(skills.rawValue.nonzeroBitCount) * 22
		+ (isAA ? 47 : 0)
		+ (isArt ? 33 : 0)
		+ (isArmor ? 22 : 0)
	}

	private var statsValue: UInt16 {
		UInt16(tier * 24)
		+ UInt16(softAtk) * 4
		+ UInt16(hardAtk) * 5
		+ UInt16(airAtk) * 6
		+ UInt16(navAtk) * 6
		+ UInt16(groundDef) * 4
		+ UInt16(airDef) * 4
		+ UInt16(ini) * 4
		+ UInt16(mov) * 6
		+ UInt16(rng * rng) * 4
	}
}

extension Unit {

	mutating func reset() {
		hp = maxHP
		ap = maxAP
		mp = maxMP
		ammo = maxAmmo
		ent = 0
		armOverwatch()
	}

	mutating func armOverwatch() {
		self[.overwatch] = isAA && canMove
	}

	@discardableResult
	mutating func heal(_ amount: UInt8) -> UInt8 {
		hp.increment(
			by: amount,
			cap: maxHP
		)
	}

	mutating func promote(using d20: inout D20) {
		let all = [8 of Skills].init { i in Skills(rawValue: 1 << i) }
		let cnt = skills.rawValue.nonzeroBitCount

		if Int(lvl) > cnt, d20(.min, 2) > 9 + cnt * 3 - Int(lvl) * 2,
		   let rnd = all.compactMap(id).randomElement(using: &d20)
		{
			skills.insert(rnd)
		}
	}
}

@frozen public enum UnitType: UInt8, Hashable, Sendable {
	case supply, inf,
		 art, wheelArt, trackArt,
		 aa, wheelAA, trackAA,
		 lightWheel, lightTrack, heavyTrack,
		 heli, fighter, cas,
		 cargo, destroyer, cruiser
}

@frozen public enum MoveType: UInt8, Hashable, Sendable {
	case leg, wheel, track, air, naval
}

@frozen public enum TargetType: UInt8, Hashable, Sendable {
	case soft, hard, air, naval
}

public extension UnitType {

	var moveType: MoveType {
		switch self {
		case .inf, .art, .aa: .leg
		case .supply, .wheelArt, .wheelAA, .lightWheel: .wheel
		case .trackArt, .trackAA, .lightTrack, .heavyTrack: .track
		case .heli, .fighter, .cas: .air
		case .cargo, .destroyer, .cruiser: .naval
		}
	}

	var targetType: TargetType {
		switch self {
		case .inf, .supply, .art, .aa, .wheelAA, .wheelArt: .soft
		case .trackArt, .trackAA, .lightWheel, .lightTrack, .heavyTrack: .hard
		case .heli, .fighter, .cas: .air
		case .cargo, .destroyer, .cruiser: .naval
		}
	}

	var isArt: Bool {
		switch self {
		case .art, .wheelArt, .trackArt, .cruiser: true;
		default: false
		}
	}

	var isAA: Bool {
		switch self {
		case .aa, .wheelAA, .trackAA, .fighter, .destroyer: true;
		default: false
		}
	}

	var isAir: Bool {
		switch self {
		case .heli, .fighter, .cas: true
		default: false
		}
	}

	var isNaval: Bool {
		switch self {
		case .cargo, .destroyer, .cruiser: true
		default: false
		}
	}
}

@frozen public enum UnitModel: UInt8, Hashable {
	case none

	// Common
	case truck, regular, engineer, fpv, art155, cargo, destroyer, cruiser

	// Allies
	case ranger, delta, m2A2, m113, m48, m1A1, m1A2,
		 m777, m109, m147, patriot, mh6, f16, f35, mq9

	// Axis
	case ksk, p1sun, fennek, boxer, marder, cv9035, strf90, kf41, pzh, mars,
		 leo1a5, leo2a4, leo2a7, strv122, kf51,
		 bofors, nasams, lvkv90, skeldar, skeldarm, nh90, gripen

	// Soviet
	case militia, speznas, brdm2, bmp, t55, t72, t90m, art105, sp105, neva, s300,
		 tunguska, mi8, mi24, orlan, mig29, su57, su25, su27
}

extension Unit: DeadOrAlive {
	public var alive: Bool { hp > 0 }
}

public struct UID: Equatable, BitwiseCopyable, Sendable {
	public var rawValue: UInt8

	public init(_ value: UInt8) { rawValue = value }
}

public extension UID {

	static let none = UID(255)

	var index: Int { Int(rawValue) }
}

public extension Int {
	var uid: UID { UID(UInt8(self)) }
}

public extension InlineArray where Element == Unit, count == 16 {

	subscript(_ xy: XY) -> (UID, Unit)? {
		let i = xy.x + xy.y * 4
		let u = self[i]
		return u.alive ? (i.uid, u) : nil
	}
}

public extension CArray where capacity == 192 {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}

public extension InlineArray where count == 192 {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}

public extension Array {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}
