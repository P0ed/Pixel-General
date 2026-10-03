/// Concrete unit silhouettes, authored nose-first along `+x`.
public enum Units {

	public enum Faction: CaseIterable, Sendable { case european, american, soviet }

	/// Vehicle families, with a different representative for each faction.
	public enum Kind: String, CaseIterable, Sendable {
		case tank
		case scoutCar
		case wheeledCarrier
		case trackedCarrier
		case ifv
		case supply
		case towedArtillery
		case selfPropelledArtillery
		case rocketArtillery
		case towedAA
		case selfPropelledAA
		case missileAA
		case helicopter
		case rotorUAV
		case fixedWingUAV
		case fighter
		case attackAircraft
		case cargo
		case destroyer
		case cruiser

		public var name: String {
			switch self {
			case .tank: "Tanks"
			case .scoutCar: "Scout cars"
			case .wheeledCarrier: "Wheeled carriers"
			case .trackedCarrier: "Tracked carriers"
			case .ifv: "Infantry fighting vehicles"
			case .supply: "Supply trucks"
			case .towedArtillery: "Towed artillery"
			case .selfPropelledArtillery: "Self-propelled artillery"
			case .rocketArtillery: "Rocket artillery"
			case .towedAA: "Towed anti-aircraft guns"
			case .selfPropelledAA: "Self-propelled anti-aircraft guns"
			case .missileAA: "Surface-to-air launchers"
			case .helicopter: "Helicopters"
			case .rotorUAV: "Rotor UAVs"
			case .fixedWingUAV: "Fixed-wing UAVs"
			case .fighter: "Fighters"
			case .attackAircraft: "Attack aircraft"
			case .cargo: "Naval transports"
			case .destroyer: "Destroyers"
			case .cruiser: "Cruisers"
			}
		}

		public var variants: [Shape] {
			switch self {
			case .tank: [.leo2a6, .m1A2, .t72, .leo1, .strv103, .strv122, .kf51, .m48, .m1A1, .t55, .t90m]
			case .scoutCar: [.fennek, .m1117, .brdm2]
			case .wheeledCarrier: [.boxer, .stryker, .btr80]
			case .trackedCarrier: [.fv432, .m113, .mtLb]
			case .ifv: [.strf90, .m2A2, .bmp2, .marder, .cv9035, .kf41]
			case .supply: [.manKat1, .m35, .ural4320]
			case .towedArtillery: [.fh70, .m777, .d30, .m198, .d20]
			case .selfPropelledArtillery: [.pzh2000, .m109, .akatsiya]
			case .rocketArtillery: [.m270, .m142, .bm21]
			case .towedAA: [.boforsL70, .m167, .zu23]
			case .selfPropelledAA: [.lvkv90, .m163, .tunguska, .gepard]
			case .missileAA: [.nasams, .patriot, .neva, .s300]
			case .helicopter: [.nh90, .mh6, .mi8, .mi24]
			case .rotorUAV: [.skeldar, .mq8, .ka137, .skeldarm]
			case .fixedWingUAV: [.bayraktar, .mq9, .orlan]
			case .fighter: [.gripen, .f16, .mig29, .f35, .su57]
			case .attackAircraft: [.tornado, .a10, .su25, .su27]
			case .cargo: [.karelDoorman, .bobHope, .ropucha]
			case .destroyer: [.type45, .arleighBurke, .sovremenny]
			case .cruiser: [.deZevenProvincien, .ticonderoga, .slava]
			}
		}

		/// A distinct representative for each of the game's three equipment families.
		public func variant(for faction: Faction) -> Shape {
			switch faction {
			case .european: variants[0]
			case .american: variants[1]
			case .soviet: variants[2]
			}
		}
	}

	public enum Shape: UInt8, Sendable, CaseIterable {
		case leo1, leo2a6, strv103, strv122, kf51, m48, m1A1, m1A2, t55, t72, t90m
		case fennek, m1117, brdm2
		case boxer, stryker, btr80
		case fv432, m113, mtLb
		case marder, strf90, cv9035, kf41, m2A2, bmp2
		case manKat1, m35, ural4320
		case fh70, m777, d30, m198, d20
		case pzh2000, m109, akatsiya
		case m270, m142, bm21
		case boforsL70, m167, zu23
		case lvkv90, m163, tunguska, gepard
		case nasams, patriot, neva, s300
		case nh90, mh6, mi8, mi24
		case skeldar, mq8, ka137, skeldarm
		case bayraktar, mq9, orlan
		case gripen, f16, mig29, f35, su57
		case tornado, a10, su25, su27
		case karelDoorman, bobHope, ropucha
		case type45, arleighBurke, sovremenny
		case deZevenProvincien, ticonderoga, slava
		case rifleman, special, fpv, engineer

		public var name: String {
			switch self {
			case .leo1: "Leopard 1A5"
			case .leo2a6: "Leopard 2A6"
			case .strv103: "Strv 103"
			case .strv122: "Strv 122"
			case .kf51: "KF51 Panther"
			case .m48: "M48 Patton"
			case .m1A1: "M1A1"
			case .m1A2: "M1A2"
			case .t55: "T-55"
			case .t72: "T-72B"
			case .t90m: "T-90M"
			case .fennek: "Fennek"
			case .m1117: "M1117"
			case .brdm2: "BRDM-2"
			case .boxer: "Boxer"
			case .stryker: "Stryker"
			case .btr80: "BTR-80"
			case .fv432: "FV432"
			case .m113: "M113"
			case .mtLb: "MT-LB"
			case .marder: "Marder"
			case .strf90: "Strf 9040"
			case .cv9035: "CV9035"
			case .kf41: "KF41 Lynx"
			case .m2A2: "M2A2 Bradley"
			case .bmp2: "BMP-2"
			case .manKat1: "MAN KAT1"
			case .m35: "M35"
			case .ural4320: "Ural-4320"
			case .fh70: "FH70"
			case .m777: "M777"
			case .d30: "D-30"
			case .m198: "M198"
			case .d20: "D-20"
			case .pzh2000: "PzH 2000"
			case .m109: "M109A7"
			case .akatsiya: "2S3 Akatsiya"
			case .m270: "M270 MARS"
			case .m142: "M142 HIMARS"
			case .bm21: "BM-21 Grad"
			case .boforsL70: "Bofors L/70"
			case .m167: "M167 VADS"
			case .zu23: "ZU-23-2"
			case .lvkv90: "Lvkv 90"
			case .m163: "M163 VADS"
			case .tunguska: "2S6 Tunguska"
			case .gepard: "Gepard"
			case .nasams: "NASAMS"
			case .patriot: "Patriot"
			case .neva: "S-125 Neva"
			case .s300: "S-300"
			case .nh90: "NH90"
			case .mh6: "MH-6"
			case .mi8: "Mi-8"
			case .mi24: "Mi-24"
			case .skeldar: "Skeldar V-200"
			case .mq8: "MQ-8 Fire Scout"
			case .ka137: "Ka-137"
			case .skeldarm: "Skeldar M"
			case .bayraktar: "Bayraktar TB2"
			case .mq9: "MQ-9 Reaper"
			case .orlan: "Orlan-10"
			case .gripen: "JAS 39 Gripen"
			case .f16: "F-16"
			case .mig29: "MiG-29"
			case .f35: "F-35"
			case .su57: "Su-57"
			case .tornado: "Tornado"
			case .a10: "A-10"
			case .su25: "Su-25"
			case .su27: "Su-27"
			case .karelDoorman: "Karel Doorman"
			case .bobHope: "Bob Hope"
			case .ropucha: "Ropucha"
			case .type45: "Type 45"
			case .arleighBurke: "Arleigh Burke"
			case .sovremenny: "Sovremenny"
			case .deZevenProvincien: "De Zeven Provinciën"
			case .ticonderoga: "Ticonderoga"
			case .slava: "Slava"
			case .rifleman: "Rifleman"
			case .special: "Special forces"
			case .fpv: "FPV operator"
			case .engineer: "Engineer"
			}
		}

		public var model: Model {
			switch self {
			case .leo1: Units.leo1
			case .leo2a6: Units.leo2a6
			case .strv103: Units.strv103
			case .strv122: Units.strv122
			case .kf51: Units.kf51
			case .m48: Units.m48
			case .m1A1: Units.m1A1
			case .m1A2: Units.m1A2
			case .t55: Units.t55
			case .t72: Units.t72
			case .t90m: Units.t90m
			case .fennek: Units.fennek
			case .m1117: Units.m1117
			case .brdm2: Units.brdm2
			case .boxer: Units.boxer
			case .stryker: Units.stryker
			case .btr80: Units.btr80
			case .fv432: Units.fv432
			case .m113: Units.m113
			case .mtLb: Units.mtLb
			case .marder: Units.marder
			case .strf90: Units.strf90
			case .cv9035: Units.cv9035
			case .kf41: Units.kf41
			case .m2A2: Units.m2A2
			case .bmp2: Units.bmp2
			case .manKat1: Units.manKat1
			case .m35: Units.m35
			case .ural4320: Units.ural4320
			case .fh70: Units.fh70
			case .m777: Units.m777
			case .d30: Units.d30
			case .m198: Units.m198
			case .d20: Units.d20
			case .pzh2000: Units.pzh2000
			case .m109: Units.m109
			case .akatsiya: Units.akatsiya
			case .m270: Units.m270
			case .m142: Units.m142
			case .bm21: Units.bm21
			case .boforsL70: Units.boforsL70
			case .m167: Units.m167
			case .zu23: Units.zu23
			case .lvkv90: Units.lvkv90
			case .m163: Units.m163
			case .tunguska: Units.tunguska
			case .gepard: Units.gepard
			case .nasams: Units.nasams
			case .patriot: Units.patriot
			case .neva: Units.neva
			case .s300: Units.s300
			case .nh90: Aircraft.nh90
			case .mh6: Aircraft.mh6
			case .mi8: Aircraft.mi8
			case .mi24: Aircraft.mi24
			case .skeldar: Aircraft.skeldar
			case .mq8: Aircraft.mq8
			case .ka137: Aircraft.ka137
			case .skeldarm: Aircraft.skeldarm
			case .bayraktar: Aircraft.bayraktar
			case .mq9: Aircraft.mq9
			case .orlan: Aircraft.orlan
			case .gripen: Aircraft.gripen
			case .f16: Aircraft.f16
			case .mig29: Aircraft.mig29
			case .f35: Aircraft.f35
			case .su57: Aircraft.su57
			case .tornado: Aircraft.tornado
			case .a10: Aircraft.a10
			case .su25: Aircraft.su25
			case .su27: Aircraft.su27
			case .karelDoorman: Ships.karelDoorman
			case .bobHope: Ships.bobHope
			case .ropucha: Ships.ropucha
			case .type45: Ships.type45
			case .arleighBurke: Ships.arleighBurke
			case .sovremenny: Ships.sovremenny
			case .deZevenProvincien: Ships.deZevenProvincien
			case .ticonderoga: Ships.ticonderoga
			case .slava: Ships.slava
			case .rifleman: Infantry.rifleman
			case .special: Infantry.special
			case .fpv: Infantry.fpv
			case .engineer: Infantry.engineer
			}
		}

		public var flies: Bool {
			switch self {
			case .nh90, .mh6, .mi8, .mi24, .skeldar, .mq8, .ka137, .skeldarm, .bayraktar, .mq9, .orlan, .gripen, .f16, .mig29, .f35, .su57, .tornado, .a10, .su25, .su27: true
			default: false
			}
		}
	}

	public enum Tone {
		public static let body: UInt8 = 200
		public static let turret: UInt8 = 180
		public static let barrel: UInt8 = 160
		public static let cargo: UInt8 = 190
		public static let glass: UInt8 = 140
		public static let running: UInt8 = 60
		public static let wheel: UInt8 = 90
		public static let antenna: UInt8 = 70
	}
}
