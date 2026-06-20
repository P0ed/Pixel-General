public extension Unit {

	func country(_ country: Country) -> Self {
		modifying(self, { u in u.country = country })
	}

	func traits(_ traits: Traits) -> Self {
		modifying(self, { u in u.traits.formUnion(traits) })
	}

	static func inf1(_ country: Country) -> Self {
		switch country.team {
		case .axis: .regular
		case .allies: .ranger
		case .soviet: .militia
		case .none: .empty
		}
	}

	static func inf2(_ country: Country) -> Self {
		switch country.team {
		case .axis: .engineer
		case .allies: .engineer
		case .soviet: .regular
		case .none: .empty
		}
	}

	static func inf3(_ country: Country) -> Self {
		switch country.team {
		case .axis: .ksk.veteran
		case .allies: .delta.veteran
		case .soviet: .speznas
		case .none: .empty
		}
	}

	static func recon1(_ country: Country) -> Self? {
		switch country.team {
		case .axis: .fennek
		case .allies: nil
		case .soviet: .brdm2
		case .none: .empty
		}
	}

	static func ifv1(_ country: Country) -> Self {
		switch country.team {
		case .axis: .boxer
		case .allies: .m2A2
		case .soviet: .bmp
		case .none: .empty
		}
	}

	static func ifv2(_ country: Country) -> Self? {
		switch country {
		case .swe: .strf90
		case .ger: .kf41
		default: switch country.team {
			case .axis: .cv9035
			case .allies: nil
			case .soviet: nil
			case .none: .empty
			}
		}
	}

	static func tank1(_ country: Country) -> Self {
		switch country {
		case .ned, .den, .ukr: .leo1
		case .swe: .strv103
		case .usa, .isr: .m48
		case .pak: .m48
		case .rus: .t55
		case .irn, .ind: .t55
		default: switch country.team {
			case .axis: .leo1
			case .allies: .m48
			case .soviet: .t55
			case .none: .empty
			}
		}
	}

	static func tank2(_ country: Country) -> Self {
		switch country {
		case .swe: .strv122
		case .ger: .kf51
		case .usa, .isr: .m1A1
		case .pak: .m1A1
		case .rus: .t72
		case .irn, .ind: .t72
		default: switch country.team {
			case .axis: .leo2a6
			case .allies: .m1A1
			case .soviet: .t72
			case .none: .empty
			}
		}
	}

	static func tank3(_ country: Country) -> Self? {
		switch country {
		case .swe: .strv122
		case .ger: .kf51
		case .usa, .isr: .m1A2
		case .pak: nil
		case .rus: .t90m
		case .irn, .ind: nil
		default: switch country.team {
			case .axis: .leo2a6
			case .allies: .m1A2
			case .soviet: .t90m
			case .none: .empty
			}
		}
	}

	static func art1(_ country: Country) -> Self {
		switch country.team {
		case .axis: .art155
		case .allies: .m777
		case .soviet: .art105
		case .none: .empty
		}
	}

	static func art2(_ country: Country) -> Self {
		switch country.team {
		case .axis: .pzh
		case .allies: .m270
		case .soviet: .art155
		case .none: .empty
		}
	}

	static func air1(_ country: Country) -> Self {
		switch country.team {
		case .axis: .skeldar
		case .allies: .mh6
		case .soviet: .mi8
		case .none: .empty
		}
	}

	static func air2(_ country: Country) -> Self {
		switch country.team {
		case .axis: .nh90
		case .allies: .f16
		case .soviet: .mi24
		case .none: .empty
		}
	}

	static func air3(_ country: Country) -> Self {
		switch country.team {
		case .axis: .gripen
		case .allies: .f35
		case .soviet: .mig29
		case .none: .empty
		}
	}

	static func air4(_ country: Country) -> Self {
		switch country.team {
		case .axis: .skeldarm
		case .allies: .mq9
		case .soviet: .orlan
		case .none: .empty
		}
	}

	static func aa1(_ country: Country) -> Self {
		switch country.team {
		default: .bofors
		}
	}

	static func aa2(_ country: Country) -> Self? {
		switch country.team {
		case .axis: .lvkv90
		case .soviet: .tunguska
		case .allies: nil
		case .none: .empty
		}
	}

	static func aa3(_ country: Country) -> Self {
		switch country.team {
		case .axis: .nasams
		case .allies: .patriot
		case .soviet: .neva
		case .none: .empty
		}
	}

	var veteran: Self { lvl(2) }

	func lvl(_ lvl: UInt8) -> Self {
		modifying(self) { u in u.lvl = lvl }
	}

	func skills(_ skills: Skills) -> Self {
		modifying(self) { u in u.skills.formUnion(skills) }
	}

	static let truck = Unit(
		model: .truck,
		type: .supply,
		mov: 8,
		groundDef: 3,
		airDef: 1,
		traits: .transport
	)

	static let regular = Unit(
		model: .regular,
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

	static let engineer = Unit(
		model: .engineer,
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

	static let art155 = Unit(
		model: .art155,
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
}
