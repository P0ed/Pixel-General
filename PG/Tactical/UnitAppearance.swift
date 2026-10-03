import COR
import GFX

extension Unit {

	/// Named platforms have their own geometry. Common equipment uses the faction's variant.
	var vehicle: Units.Shape? {
		switch model {
		case .none: nil
		case .truck: Units.Kind.supply.variant(for: artFaction)

		// Infantry and FPV keep their existing sprites.
		case .regular, .engineer, .ranger, .militia: .rifleman
		case .delta, .ksk, .speznas: .special
		case .fpv, .p1sun: .quad

		case .art155:
			switch country.team {
			case .soviet: .d20
			case .allies: .m198
			default: .fh70
			}
		case .m777: .m777
		case .art105: .d30
		case .sp105: .akatsiya
		case .pzh: .pzh2000
		case .m109: .m109
		case .mars: .m270
		case .m147: .m142

		case .patriot: .patriot
		case .nasams: .nasams
		case .neva: .neva
		case .s300: .s300
		case .bofors: Units.Kind.towedAA.variant(for: artFaction)
		case .lvkv90: .lvkv90
		case .tunguska: .tunguska

		case .fennek: .fennek
		case .brdm2: .brdm2
		case .boxer: .boxer
		case .m2A2: .m2A2
		case .m113: .m113
		case .marder: .marder
		case .bmp: .bmp2
		case .strf90: .strf90
		case .cv9035: .cv9035
		case .kf41: .kf41

		case .m48: .m48
		case .m1A1: .m1A1
		case .m1A2: .m1A2
		case .kf51: .kf51
		case .leo2a6: .leo2a6
		case .strv122: .strv122
		case .leo1: .leo1
		case .strv103: .strv103
		case .t55: .t55
		case .t72: .t72
		case .t90m: .t90m

		case .skeldar: .skeldar
		case .skeldarm: .skeldarm
		case .mh6: .mh6
		case .nh90: .nh90
		case .mi8: .mi8
		case .mi24: .mi24
		case .mq9: .mq9
		case .orlan: .orlan
		case .f16: .f16
		case .f35: .f35
		case .gripen: .gripen
		case .mig29: .mig29
		case .su57: .su57
		case .su25: .su25
		case .su27: .su27

		case .cargo: Units.Kind.cargo.variant(for: artFaction)
		case .destroyer: Units.Kind.destroyer.variant(for: artFaction)
		case .cruiser: Units.Kind.cruiser.variant(for: artFaction)
		}
	}

	private var artFaction: Units.Faction {
		switch country.team {
		case .allies: .american
		case .soviet: .soviet
		case .axis, .none: .european
		}
	}
}
