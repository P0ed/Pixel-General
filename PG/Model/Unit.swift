struct UID: Equatable {
	var rawValue: Int8

	init(_ value: Int8) { rawValue = value }
}

struct Unit: Equatable {
	var country: Country = .default
	var hp: UInt8 = 0
	var mp: UInt8 = 0
	var ap: UInt8 = 0
	var ammo: UInt8 = 0
	var ent: UInt8 = 0
	var exp: UInt16 = 0
	var kills: UInt16 = 0
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
	var skills: Skills = []
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
}

struct Skills: OptionSet, Equatable {
	var rawValue: UInt16

	static var leadership: Self { .init(rawValue: 1 << 0) }
	static var recon: Self { .init(rawValue: 1 << 1) }
	static var crit: Self { .init(rawValue: 1 << 2) }
	static var evasion: Self { .init(rawValue: 1 << 3) }
	static var regen: Self { .init(rawValue: 1 << 4) }
	static var mountaineer: Self { .init(rawValue: 1 << 5) }
	static var mhtn: Self { .init(rawValue: 1 << 6) }
	static var diag: Self { .init(rawValue: 1 << 7) }
}

extension Unit {

	var isAir: Bool { switch type { case .heli, .jet: true; default: false } }
	var untouched: Bool { fullAP && fullMP }
	var hasActions: Bool { canMove || canAttack }
	var canMove: Bool { mp > 0 }
	var canAttack: Bool { ap > 0 }
	var spot: UInt8 { self[.radar] ? 3 : 2 }

	var maxHP: UInt8 { 0xF }
	var maxAP: UInt8 { rng == 0 ? 0 : 1 }
	var maxMP: UInt8 { isAir ? 2 : 1 }

	var fullHP: Bool { hp == maxHP }
	var fullAP: Bool { ap == maxAP }
	var fullMP: Bool { mp == maxMP }
	var fullAmmo: Bool { ammo == maxAmmo }

	var maxAmmo: UInt8 {
		guard rng > 0 else { return 0 }

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

	var isArmor: Bool {
		switch type {
		case .lightWheel, .lightTrack, .heavyTrack: !self[.art] && !self[.aa];
		default: false
		}
	}

	var entDef: UInt8 {
		ent / 4
	}

	var entRate: UInt8 {
		switch type {
		case .soft: 4
		case .softWheel, .lightWheel, .lightTrack: 3
		case .heavyTrack: 2
		case .heli, .jet: 0
		}
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
		modifying(8) { lvl in lvl.decrement(by: UInt8(exp.leadingZeroBitCount)) }
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
		case .soft, .softWheel: softAtk
		case .lightWheel, .lightTrack, .heavyTrack: hardAtk
		case .heli, .jet: airAtk
		}
	}

	func def(_ src: Unit) -> UInt8 {
		src.isAir ? airDef : groundDef
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

		if Int(lvl) > cnt, d20(.min(2)) > 9 + cnt * 3 - Int(lvl) * 2,
		   let rnd = all.compactMap(id).randomElement(using: &d20)
		{
			skills.insert(rnd)
		}
	}

	var cost: UInt16 {
		UInt16(lvl + 3) * (typeCost + traitCost + sum * sumMult) / (self[.aux] ? 6 : 3)
	}

	private var sumMult: UInt16 {
		self[.art] ? 4 : 3
	}

	private var traitCost: UInt16 {
		UInt16(traits.rawValue.nonzeroBitCount) * 15
	}

	private var skillCost: UInt16 {
		UInt16(skills.rawValue.nonzeroBitCount) * 18
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
		UInt16(softAtk + hardAtk + airAtk + groundDef + airDef + ini + mov + rng)
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

extension CArray where capacity == 128 {
	subscript(_ id: UID) -> Element {
		get { self[id.index] }
		set { self[id.index] = newValue }
	}
}

extension InlineArray where count == 128 {
	subscript(_ id: UID) -> Element {
		get { self[id.index] }
		set { self[id.index] = newValue }
	}
}

extension Array {
	subscript(_ id: UID) -> Element {
		get { self[id.index] }
		set { self[id.index] = newValue }
	}
}

extension UID {

	static let none = UID(-1)

	var index: Int { Int(rawValue) }
}
extension Int { var uid: UID { UID(Int8(clamping: self)) } }
