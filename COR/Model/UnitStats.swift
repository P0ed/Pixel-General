/// The static, per-model half of a unit: the fields that are identical across
/// every instance of a model. `Unit` stores only a `UnitModel` and reads these
/// through ``Unit/stats``, so editing ``table`` rebalances every unit in play —
/// including units restored from a save, which persist only the model id.
public struct UnitStats {
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
}

public extension UnitStats {

	/// Live stat table keyed by model. Mutable so stats can be tweaked
	/// mid-game; restore the shipped values with `UnitStats.table = .defaults`.
	static var table = defaults

	// Split per faction: a single 50+ entry literal overwhelms the Swift
	// expression type-checker, so each chunk is built and merged separately.
	static let defaults: [UnitModel: UnitStats] = common
		.merging(allies) { a, _ in a }
		.merging(axis) { a, _ in a }
		.merging(soviet) { a, _ in a }

	private static let common: [UnitModel: UnitStats] = [
		.truck: .init(type: .supply, mov: 8, groundDef: 3, airDef: 1, traits: .transport),
		.regular: .init(type: .inf, tier: 1, mov: 3, rng: 1, ini: 4, softAtk: 7, hardAtk: 2, groundDef: 6, airDef: 4),
		.engineer: .init(type: .inf, tier: 2, mov: 3, rng: 1, ini: 5, softAtk: 8, hardAtk: 6, airAtk: 2, groundDef: 7, airDef: 5, traits: .engineer),
		.art155: .init(type: .art, tier: 1, mov: 2, rng: 3, ini: 1, softAtk: 11, hardAtk: 7, groundDef: 5, airDef: 4),
	]

	private static let allies: [UnitModel: UnitStats] = [
		.ranger: .init(type: .inf, tier: 1, mov: 3, rng: 1, ini: 5, softAtk: 8, hardAtk: 3, groundDef: 7, airDef: 4),
		.delta: .init(type: .inf, tier: 3, mov: 4, rng: 1, ini: 9, softAtk: 11, hardAtk: 5, airAtk: 2, groundDef: 9, airDef: 8, traits: .elite),
		.m2A2: .init(type: .lightTrack, tier: 1, mov: 7, rng: 1, ini: 9, softAtk: 10, hardAtk: 9, airAtk: 3, groundDef: 10, airDef: 7, traits: .transport),
		.m113: .init(type: .lightTrack, mov: 6, rng: 1, ini: 7, softAtk: 7, hardAtk: 3, airAtk: 2, groundDef: 8, airDef: 6, traits: .transport),
		.m48: .init(type: .heavyTrack, mov: 5, rng: 1, ini: 7, softAtk: 8, hardAtk: 11, groundDef: 11, airDef: 6),
		.m1A1: .init(type: .heavyTrack, tier: 1, mov: 7, rng: 1, ini: 8, softAtk: 10, hardAtk: 13, groundDef: 12, airDef: 7),
		.m1A2: .init(type: .heavyTrack, tier: 2, mov: 7, rng: 1, ini: 9, softAtk: 10, hardAtk: 15, groundDef: 13, airDef: 7, traits: .elite),
		.m777: .init(type: .art, tier: 1, mov: 2, rng: 3, ini: 1, softAtk: 11, hardAtk: 7, groundDef: 5, airDef: 4),
		.m270: .init(type: .trackArt, tier: 1, mov: 5, rng: 3, ini: 4, softAtk: 11, hardAtk: 7, groundDef: 5, airDef: 4),
		.patriot: .init(type: .aa, tier: 1, mov: 2, rng: 3, ini: 9, airAtk: 14, groundDef: 4, airDef: 7, traits: .radar),
		.mh6: .init(type: .heli, tier: 1, mov: 10, rng: 1, ini: 9, softAtk: 8, hardAtk: 9, airAtk: 9, groundDef: 8, airDef: 7, traits: .transport),
		.f16: .init(type: .fighter, tier: 1, mov: 12, rng: 2, ini: 11, softAtk: 9, hardAtk: 11, airAtk: 13, groundDef: 9, airDef: 9, traits: .radar),
		.f35: .init(type: .fighter, tier: 2, mov: 12, rng: 2, ini: 12, softAtk: 10, hardAtk: 13, airAtk: 15, groundDef: 11, airDef: 11, traits: .radar),
		.mq9: .init(type: .heli, tier: 2, mov: 9, ini: 5, softAtk: 7, hardAtk: 9, groundDef: 7, airDef: 6, traits: .optics),
	]

	private static let axis: [UnitModel: UnitStats] = [
		.ksk: .init(type: .inf, tier: 3, mov: 4, rng: 1, ini: 10, softAtk: 10, hardAtk: 5, airAtk: 3, groundDef: 9, airDef: 8, traits: .elite),
		.fennek: .init(type: .lightWheel, mov: 8, rng: 1, ini: 7, softAtk: 6, hardAtk: 3, airAtk: 2, groundDef: 6, airDef: 6, traits: .optics),
		.boxer: .init(type: .lightWheel, tier: 1, mov: 8, rng: 1, ini: 8, softAtk: 10, hardAtk: 9, airAtk: 3, groundDef: 9, airDef: 7, traits: .transport),
		.strf90: .init(type: .lightTrack, tier: 1, mov: 7, rng: 1, ini: 9, softAtk: 10, hardAtk: 10, airAtk: 3, groundDef: 11, airDef: 8, traits: .transport),
		.kf41: .init(type: .lightTrack, tier: 1, mov: 7, rng: 1, ini: 10, softAtk: 11, hardAtk: 10, airAtk: 5, groundDef: 12, airDef: 8, traits: .elite),
		.cv9035: .init(type: .lightTrack, tier: 1, mov: 7, rng: 1, ini: 9, softAtk: 10, hardAtk: 10, airAtk: 4, groundDef: 11, airDef: 8, traits: .transport),
		.pzh: .init(type: .trackArt, tier: 1, mov: 5, rng: 3, ini: 4, softAtk: 11, hardAtk: 7, groundDef: 6, airDef: 5),
		.leo1: .init(type: .heavyTrack, mov: 6, rng: 1, ini: 8, softAtk: 8, hardAtk: 12, groundDef: 11, airDef: 7),
		.leo2a6: .init(type: .heavyTrack, tier: 1, mov: 6, rng: 1, ini: 9, softAtk: 10, hardAtk: 15, groundDef: 13, airDef: 8, traits: .elite),
		.strv103: .init(type: .heavyTrack, mov: 6, rng: 1, ini: 7, softAtk: 7, hardAtk: 13, groundDef: 11, airDef: 7),
		.strv122: .init(type: .heavyTrack, tier: 1, mov: 6, rng: 1, ini: 9, softAtk: 10, hardAtk: 15, groundDef: 14, airDef: 8, traits: .elite),
		.kf51: .init(type: .heavyTrack, tier: 1, mov: 6, rng: 1, ini: 10, softAtk: 12, hardAtk: 16, groundDef: 14, airDef: 8, traits: .elite),
		.bofors: .init(type: .aa, mov: 2, rng: 1, ini: 7, softAtk: 7, hardAtk: 7, airAtk: 11, groundDef: 6, airDef: 7),
		.nasams: .init(type: .aa, tier: 1, mov: 2, rng: 3, ini: 9, airAtk: 14, groundDef: 4, airDef: 7, traits: .radar),
		.lvkv90: .init(type: .trackAA, tier: 1, mov: 7, rng: 1, ini: 9, softAtk: 9, hardAtk: 8, airAtk: 10, groundDef: 10, airDef: 9, traits: .radar),
		.skeldar: .init(type: .heli, tier: 1, mov: 9, ini: 6, groundDef: 7, airDef: 6, traits: [.radar, .optics]),
		.skeldarm: .init(type: .heli, tier: 2, mov: 8, ini: 6, softAtk: 5, hardAtk: 5, groundDef: 7, airDef: 6),
		.nh90: .init(type: .heli, mov: 9, rng: 1, ini: 7, softAtk: 7, hardAtk: 7, airAtk: 5, groundDef: 7, airDef: 6, traits: .transport),
		.gripen: .init(type: .fighter, tier: 1, mov: 12, rng: 2, ini: 12, softAtk: 9, hardAtk: 11, airAtk: 12, groundDef: 10, airDef: 10, traits: .radar),
	]

	private static let soviet: [UnitModel: UnitStats] = [
		.militia: .init(type: .inf, mov: 3, rng: 1, ini: 3, softAtk: 5, hardAtk: 1, groundDef: 5, airDef: 3),
		.speznas: .init(type: .inf, tier: 2, mov: 4, rng: 1, ini: 8, softAtk: 9, hardAtk: 4, airAtk: 2, groundDef: 8, airDef: 7, traits: .elite),
		.brdm2: .init(type: .lightWheel, mov: 8, rng: 1, ini: 7, softAtk: 7, hardAtk: 5, airAtk: 2, groundDef: 7, airDef: 6),
		.bmp: .init(type: .lightTrack, mov: 6, rng: 1, ini: 7, softAtk: 8, hardAtk: 7, airAtk: 2, groundDef: 7, airDef: 6, traits: .transport),
		.t55: .init(type: .heavyTrack, mov: 5, rng: 1, ini: 6, softAtk: 7, hardAtk: 11, groundDef: 10, airDef: 5),
		.t72: .init(type: .heavyTrack, tier: 1, mov: 6, rng: 1, ini: 7, softAtk: 9, hardAtk: 13, groundDef: 11, airDef: 5),
		.t90m: .init(type: .heavyTrack, tier: 2, mov: 6, rng: 1, ini: 8, softAtk: 9, hardAtk: 14, groundDef: 12, airDef: 6),
		.art105: .init(type: .art, mov: 2, rng: 2, ini: 1, softAtk: 9, hardAtk: 5, groundDef: 5, airDef: 4),
		.neva: .init(type: .wheelAA, mov: 7, rng: 3, ini: 8, airAtk: 12, groundDef: 4, airDef: 7),
		.s300: .init(type: .wheelAA, tier: 1, mov: 7, rng: 3, ini: 9, airAtk: 13, groundDef: 4, airDef: 8, traits: .radar),
		.tunguska: .init(type: .trackAA, mov: 7, rng: 1, ini: 8, softAtk: 7, hardAtk: 7, airAtk: 9, groundDef: 8, airDef: 8),
		.mi8: .init(type: .heli, mov: 9, rng: 1, ini: 7, softAtk: 6, hardAtk: 4, airAtk: 2, groundDef: 6, airDef: 6, traits: .transport),
		.mi24: .init(type: .heli, tier: 1, mov: 9, rng: 1, ini: 8, softAtk: 9, hardAtk: 9, airAtk: 7, groundDef: 8, airDef: 7, traits: .transport),
		.orlan: .init(type: .heli, tier: 2, mov: 9, ini: 5, groundDef: 7, airDef: 6, traits: .optics),
		.mig29: .init(type: .fighter, mov: 12, rng: 2, ini: 8, softAtk: 7, hardAtk: 8, airAtk: 10, groundDef: 9, airDef: 8, traits: .radar),
		.su57: .init(type: .fighter, tier: 2, mov: 12, rng: 2, ini: 9, softAtk: 8, hardAtk: 10, airAtk: 12, groundDef: 9, airDef: 9, traits: .radar),
		.su27: .init(type: .cas, mov: 11, rng: 2, ini: 10, softAtk: 9, hardAtk: 12, airAtk: 7, groundDef: 10, airDef: 7, traits: .radar),
	]
}
