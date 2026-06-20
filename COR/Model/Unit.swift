public struct Unit: Equatable {
	public var country: Country = .default
	public var hp: UInt8 = 0
	public var mp: UInt8 = 0
	public var ap: UInt8 = 0
	public var ammo: UInt8 = 0
	public var ent: UInt8 = 0
	public var exp: UInt16 = 0

	public var kills: UInt16 = 0
	public var type: UnitType = .supply
	public var tier: UInt8 = 0
	public var mov: UInt8 = 0
	public var rng: UInt8 = 0
	public var ini: UInt8 = 0
	public var softAtk: UInt8 = 0

	public var hardAtk: UInt8 = 0
	public var airAtk: UInt8 = 0
	public var groundDef: UInt8 = 0
	public var airDef: UInt8 = 0
	public var traits: Traits = []
	public var skills: Skills = []
}

public struct Traits: OptionSet, Equatable {
	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension Traits {
	static var aux: Self { .init(rawValue: 1 << 0) }
	static var engineer: Self { .init(rawValue: 1 << 1) }
	static var optics: Self { .init(rawValue: 1 << 2) }
	static var atgm: Self { .init(rawValue: 1 << 3) }
	static var aam: Self { .init(rawValue: 1 << 4) }
	static var elite: Self { .init(rawValue: 1 << 5) }
	static var transport: Self { .init(rawValue: 1 << 6) }
	static var radar: Self { .init(rawValue: 1 << 7) }
}

public struct Skills: OptionSet, Equatable {
	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension Skills {
	static var leadership: Self { .init(rawValue: 1 << 0) }
	static var recon: Self { .init(rawValue: 1 << 1) }
	static var crit: Self { .init(rawValue: 1 << 2) }
	static var evasion: Self { .init(rawValue: 1 << 3) }
	static var regen: Self { .init(rawValue: 1 << 4) }
	static var mountaineer: Self { .init(rawValue: 1 << 5) }
	static var mhtn: Self { .init(rawValue: 1 << 6) }
	static var diag: Self { .init(rawValue: 1 << 7) }
}

public extension Unit {

	static var empty: Self { .init() }

	var isAir: Bool { switch type { case .heli, .fighter, .cas: true; default: false } }
	var untouched: Bool { fullAP && fullMP }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { mp > 0 }
	var canAttack: Bool { ap > 0 }

	var spot: UInt8 { self[.optics] ? 3 : 2 }

	var maxHP: UInt8 { 0xF }
	var maxAP: UInt8 { rng == 0 ? 0 : 1 }
	var maxMP: UInt8 { isAir ? 2 : 1 }

	var fullHP: Bool { hp == maxHP }
	var fullAP: Bool { ap == maxAP }
	var fullMP: Bool { mp == maxMP }
	var fullAmmo: Bool { ammo == maxAmmo }

	var maxAmmo: UInt8 {
		switch type {
		case .supply: 0
		case .fighter, .cas: rng > 1 ? 2 : 3
		case .heli: rng > 0 ? 3 : 0
		case .art: 6
		case .wheelArt, .trackArt: 5
		case .aa: rng > 1 ? 5 : 7
		case .wheelAA, .trackAA: rng > 1 ? 4 : 6
		case .inf: 7
		case .lightWheel: 7
		case .lightTrack: 7
		case .heavyTrack: 7
		}
	}

	var isArmor: Bool {
		switch type {
		case .lightWheel, .lightTrack, .heavyTrack: true;
		default: false
		}
	}

	var canAttackAfterMove: Bool {
		switch type {
		case .art, .aa: false
		default: true
		}
	}

	var isArt: Bool {
		switch type {
		case .art, .wheelArt, .trackArt: true;
		default: false
		}
	}

	var isAA: Bool {
		switch type {
		case .aa, .wheelAA, .trackAA, .fighter: true;
		default: false
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
		switch type {
		case .supply, .inf: self[.engineer] ? 8 : 4
		case .art, .aa, .wheelArt, .wheelAA, .lightWheel, .lightTrack: self[.engineer] ? 6 : 3
		case .heavyTrack, .trackAA, .trackArt: self[.engineer] ? 4 : 2
		case .heli, .fighter, .cas: 0
		}
	}

	var entDamage: UInt8 {
		self[.engineer] ? 8 : 4
	}

	subscript(_ ts: Traits) -> Bool {
		get { !traits.intersection(ts).isEmpty }
		set { newValue ? traits.formUnion(ts) : traits.subtract(ts) }
	}

	subscript(_ ss: Skills) -> Bool {
		get { !skills.intersection(ss).isEmpty }
		set { newValue ? skills.formUnion(ss) : skills.subtract(ss) }
	}

	var lvl: UInt8 {
		get {
			modifying(8) { lvl in lvl.decrement(by: UInt8(exp.leadingZeroBitCount)) }
		}
		set {
			exp = newValue == 0 ? 0 : 1 << (7 + newValue)
		}
	}

	var subLvl: UInt8 {
		let lvl = lvl
		let target: UInt16 = 1 << (8 + lvl)
		let zero: UInt16 = lvl == 0 ? 0 : 1 << (7 + lvl)
		let req = target - zero
		let has = exp > zero ? exp - zero : 0
		return min(9, UInt8(clamping: has * 10 / req))
	}

	func atk(_ dst: Unit) -> UInt8 {
		switch dst.type {
		case .inf, .supply, .art, .aa, .wheelAA, .wheelArt:
			softAtk > 0 ? softAtk + lvl : 0
		case .trackArt, .trackAA, .lightWheel, .lightTrack, .heavyTrack:
			hardAtk > 0 ? hardAtk + (isArmor ? lvl : (lvl / 2)) : 0
		case .heli, .fighter, .cas:
			airAtk > 0 ? airAtk + (isAA ? lvl : (lvl / 2)) : 0
		}
	}

	func def(_ src: Unit) -> UInt8 {
		(src.isAir ? airDef : groundDef) + lvl / 2
	}

	var cost: UInt16 {
		(typeCost + traitCost + skillCost + weightedStats) / (self[.aux] ? 7 : 4)
	}

	private var traitCost: UInt16 {
		UInt16(traits.rawValue.nonzeroBitCount) * 15
	}

	private var skillCost: UInt16 {
		UInt16(skills.rawValue.nonzeroBitCount) * 15
	}

	private var typeCost: UInt16 {
		switch type {
		case .inf, .aa, .art: 10
		case .supply, .wheelAA, .wheelArt, .lightWheel: 100
		case .trackAA, .lightTrack: 150
		case .trackArt, .heavyTrack: 220
		case .heli: 270
		case .fighter, .cas: 330
		}
	}

	private var weightedStats: UInt16 {
		UInt16(lvl + 4) * (
			UInt16(softAtk * 4)
			+ UInt16(hardAtk * 5)
			+ UInt16(airAtk * 6)
			+ UInt16(groundDef * 4)
			+ UInt16(airDef * 4)
			+ UInt16(ini * 4)
			+ UInt16(mov * 4)
			+ UInt16(rng * 7)
		)
	}
}

extension Unit {

	mutating func reset() {
		hp = maxHP
		ap = maxAP
		mp = maxMP
		ammo = maxAmmo
		ent = 0
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

@frozen public enum UnitType: UInt8, Hashable {
	case supply, inf,
		 art, wheelArt, trackArt,
		 aa, wheelAA, trackAA,
		 lightWheel, lightTrack, heavyTrack,
		 heli, fighter, cas
}

extension Unit: DeadOrAlive {
	public var alive: Bool { hp > 0 }
}

public struct UID: Equatable, BitwiseCopyable {
	public var rawValue: Int8

	public init(_ value: Int8) { rawValue = value }
}

public extension UID {

	static let none = UID(-1)

	var index: Int { Int(rawValue) }
}

public extension Int {
	var uid: UID { UID(Int8(self)) }
}

public extension InlineArray where Element == Unit, count == 16 {

	subscript(_ xy: XY) -> (UID, Unit)? {
		let i = xy.x + xy.y * 4
		let u = self[i]
		return u.alive ? (i.uid, u) : nil
	}
}

public extension CArray where capacity == 128 {
	subscript(_ id: UID) -> Element {
		_read { yield self[id.index] }
		_modify { yield &self[id.index] }
	}
}

public extension InlineArray where count == 128 {
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
