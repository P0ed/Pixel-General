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

public struct Traits: OptionSet, Equatable {
	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension Traits {
	static var transport: Self { .init(rawValue: 1 << 0) }
	static var elite: Self { .init(rawValue: 1 << 1) }
	static var engineer: Self { .init(rawValue: 1 << 2) }
	static var optics: Self { .init(rawValue: 1 << 3) }
	static var radar: Self { .init(rawValue: 1 << 4) }
	static var atgm: Self { .init(rawValue: 1 << 5) }
	static var aam: Self { .init(rawValue: 1 << 6) }
}

public extension UnitStats {

	// MARK: Common
	@safe nonisolated(unsafe) static let truck = UnitStats(
		type: .supply,
		mov: 8,
		groundDef: 3,
		airDef: 1,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let regular = UnitStats(
		type: .inf,
		tier: 1,
		mov: 3,
		rng: 1,
		ini: 4,
		softAtk: 7,
		hardAtk: 2,
		groundDef: 6,
		airDef: 4
	)
	@safe nonisolated(unsafe) static let engineer = UnitStats(
		type: .inf,
		tier: 2,
		mov: 3,
		rng: 1,
		ini: 5,
		softAtk: 8,
		hardAtk: 6,
		airAtk: 2,
		groundDef: 7,
		airDef: 5,
		traits: .engineer
	)
	@safe nonisolated(unsafe) static let art155 = UnitStats(
		type: .art,
		tier: 1,
		mov: 2,
		rng: 3,
		ini: 1,
		softAtk: 11,
		hardAtk: 7,
		groundDef: 5,
		airDef: 4
	)
	@safe nonisolated(unsafe) static let cargo = UnitStats(
		type: .art,
		tier: 1,
		mov: 6,
		rng: 3,
		ini: 1,
		groundDef: 6,
		airDef: 3
	)
	@safe nonisolated(unsafe) static let destroyer = UnitStats(
		type: .cruiser,
		tier: 2,
		mov: 7,
		rng: 2,
		ini: 9,
		softAtk: 10,
		hardAtk: 14,
		groundDef: 12,
		airDef: 9
	)
	@safe nonisolated(unsafe) static let cruiser = UnitStats(
		type: .cruiser,
		tier: 2,
		mov: 6,
		rng: 4,
		ini: 8,
		softAtk: 12,
		hardAtk: 16,
		groundDef: 16,
		airDef: 8
	)
}

public extension UnitStats {

	@safe nonisolated(unsafe) static let table: [256 of UnitStats] = .init { i in
		guard let model = UnitModel(rawValue: UInt8(i)) else { return .init() }
		return switch model {

		case .none: .init()

		// Common
		case .truck: .truck
		case .regular: .regular
		case .engineer: .engineer
		case .art155: .art155
		case .cargo: .cargo
		case .destroyer: .destroyer
		case .cruiser: .cruiser

		// Allies
		case .ranger: .ranger
		case .delta: .delta
		case .m2A2: .m2A2
		case .m113: .m113
		case .m48: .m48
		case .m1A1: .m1A1
		case .m1A2: .m1A2
		case .m777: .m777
		case .m270: .m270
		case .patriot: .patriot
		case .mh6: .mh6
		case .f16: .f16
		case .f35: .f35
		case .mq9: .mq9

		// Axis
		case .ksk: .ksk
		case .fennek: .fennek
		case .boxer: .boxer
		case .strf90: .strf90
		case .strf90v: .strf90v
		case .kf41: .kf41
		case .cv9035: .cv9035
		case .pzh: .pzh
		case .leo1: .leo1
		case .leo2a6: .leo2a6
		case .strv103: .strv103
		case .strv122: .strv122
		case .kf51: .kf51
		case .bofors: .bofors
		case .nasams: .nasams
		case .lvkv90: .lvkv90
		case .skeldar: .skeldar
		case .skeldarm: .skeldarm
		case .nh90: .nh90
		case .gripen: .gripen

		// Soviet
		case .militia: .militia
		case .speznas: .speznas
		case .brdm2: .brdm2
		case .bmp: .bmp
		case .t55: .t55
		case .t72: .t72
		case .t90m: .t90m
		case .art105: .art105
		case .sp105: .sp105
		case .neva: .neva
		case .s300: .s300
		case .tunguska: .tunguska
		case .mi8: .mi8
		case .mi24: .mi24
		case .orlan: .orlan
		case .mig29: .mig29
		case .su57: .su57
		case .su25: .su25
		case .su27: .su27
		}
	}
}
