public extension Unit {

	var aux: Self {
		modifying(self) { u in u[.aux] = true }
	}

	var veteran: Self { lvl(2) }

	func lvl(_ lvl: UInt8) -> Self {
		modifying(self) { u in u.lvl = lvl }
	}

	func skills(_ skills: Skills) -> Self {
		modifying(self) { u in u.skills.formUnion(skills) }
	}

	/// Re-equip the unit with a new platform while keeping its experience,
	/// skills, bits, and country, then refresh its supplies for that platform.
	/// The basis for HQ unit upgrades — unlike a fresh shop purchase, the crew's
	/// veterancy carries over.
	func upgraded(to model: UnitModel) -> Self {
		modifying(self) { u in
			u.model = model
			u.reset()
		}
	}

	/// Prestige charged to upgrade into `model`: the full cost of the resulting
	/// unit — the new platform carrying the crew's current experience. The old
	/// platform is not credited back.
	func upgradeCost(to model: UnitModel) -> UInt16 {
		upgraded(to: model).cost
	}
}

extension Shop {

	var inf1: Unit? {
		switch country.team {
		case .axis: Unit(model: .regular, country: country)
		case .allies: Unit(model: .ranger, country: country)
		case .soviet: Unit(model: tier < 3 ? .militia : .regular, country: country)
		case .none: nil
		}
	}

	var inf2: Unit? {
		switch country.team {
		case .axis: Unit(model: .engineer, country: country)
		case .allies: Unit(model: .engineer, country: country)
		case .soviet: Unit(model: tier < 3 ? .regular : .engineer, country: country)
		case .none: nil
		}
	}

	var inf3: Unit? {
		switch country.team {
		case .axis: Unit(model: .ksk, country: country).veteran
		case .allies: Unit(model: .delta, country: country).veteran
		case .soviet: Unit(model: .speznas, country: country)
		case .none: nil
		}
	}

	var recon1: Unit? {
		switch country.team {
		case .axis: Unit(model: .fennek, country: country)
		case .allies: nil
		case .soviet: Unit(model: .brdm2, country: country)
		case .none: nil
		}
	}

	var recon2: Unit? {
		switch country {
		case .swe: Unit(model: .strf90v, country: country)
		default: nil
		}
	}

	var ifv1: Unit? {
		switch country.team {
		case .axis: Unit(model: .boxer, country: country)
		case .allies: Unit(model: .m2A2, country: country)
		case .soviet: Unit(model: .bmp, country: country)
		case .none: nil
		}
	}

	var ifv2: Unit? {
		switch country {
		case .swe: Unit(model: .strf90, country: country)
		case .ger: Unit(model: .kf41, country: country)
		default: switch country.team {
			case .axis: Unit(model: .cv9035, country: country)
			case .allies: nil
			case .soviet: nil
			case .none: nil
			}
		}
	}

	var tank1: Unit? {
		switch country {
		case .ned, .den, .ukr: Unit(model: .leo1, country: country)
		case .swe: Unit(model: .strv103, country: country)
		case .usa, .isr: Unit(model: .m48, country: country)
		case .pak: Unit(model: .m48, country: country)
		case .rus: Unit(model: .t55, country: country)
		case .irn, .ind: Unit(model: .t55, country: country)
		default: switch country.team {
		case .axis: Unit(model: .leo1, country: country)
		case .allies: Unit(model: .m48, country: country)
		case .soviet: Unit(model: .t55, country: country)
		case .none: nil
		}
		}
	}

	var tank2: Unit? {
		switch country {
		case .swe: Unit(model: .strv122, country: country)
		case .ger: Unit(model: .kf51, country: country)
		case .usa, .isr: Unit(model: .m1A1, country: country)
		case .pak: Unit(model: .m1A1, country: country)
		case .rus: Unit(model: .t72, country: country)
		case .irn, .ind: Unit(model: .t72, country: country)
		default: switch country.team {
		case .axis: Unit(model: .leo2a6, country: country)
		case .allies: Unit(model: .m1A1, country: country)
		case .soviet: Unit(model: .t72, country: country)
		case .none: nil
		}
		}
	}

	var tank3: Unit? {
		switch country {
		case .swe: nil
		case .ger: nil
		case .usa, .isr: Unit(model: .m1A2, country: country)
		case .pak: nil
		case .rus: Unit(model: .t90m, country: country)
		case .irn, .ind: nil
		default: switch country.team {
		case .axis: nil
		case .allies: Unit(model: .m1A2, country: country)
		case .soviet: Unit(model: .t90m, country: country)
		case .none: nil
		}
		}
	}

	var art1: Unit? {
		switch country.team {
		case .axis: Unit(model: .art155, country: country)
		case .allies: Unit(model: .m777, country: country)
		case .soviet: Unit(model: tier > 1 ? .sp105 : .art105, country: country)
		case .none: nil
		}
	}

	var art2: Unit? {
		switch country.team {
		case .axis: Unit(model: .pzh, country: country)
		case .allies: Unit(model: .m109, country: country)
		case .soviet: Unit(model: .art155, country: country)
		case .none: nil
		}
	}

	var art3: Unit? {
		switch country.team {
		case .axis: Unit(model: .m270, country: country)
		case .allies: Unit(model: .m147, country: country)
		case .soviet: Unit(model: .sp105, country: country).veteran
		case .none: nil
		}
	}

	var air1: Unit? {
		switch country.team {
		case .axis: Unit(model: .skeldar, country: country)
		case .allies: Unit(model: .mh6, country: country)
		case .soviet: Unit(model: .mi8, country: country)
		case .none: nil
		}
	}

	var air2: Unit? {
		switch country.team {
		case .axis: Unit(model: .nh90, country: country)
		case .allies: Unit(model: .f16, country: country)
		case .soviet: Unit(model: .mi24, country: country)
		case .none: nil
		}
	}

	var air3: Unit? {
		switch country.team {
		case .axis: Unit(model: .gripen, country: country)
		case .allies: Unit(model: .f35, country: country)
		case .soviet: Unit(model: .mig29, country: country)
		case .none: nil
		}
	}

	var air4: Unit? {
		switch country.team {
		case .axis: Unit(model: .skeldarm, country: country)
		case .allies: Unit(model: .mq9, country: country)
		case .soviet: Unit(model: .orlan, country: country)
		case .none: nil
		}
	}

	var aa1: Unit? {
		switch country.team {
		case .axis, .allies, .soviet: Unit(model: .bofors, country: country)
		case .none: nil
		}
	}

	var aa2: Unit? {
		switch country.team {
		case .axis: Unit(model: .lvkv90, country: country)
		case .soviet: Unit(model: .tunguska, country: country)
		case .allies: nil
		case .none: nil
		}
	}

	var aa3: Unit? {
		switch country.team {
		case .axis: Unit(model: .nasams, country: country)
		case .allies: Unit(model: .patriot, country: country)
		case .soviet: Unit(model: .neva, country: country)
		case .none: nil
		}
	}

	var nav1: Unit? {
		Unit(model: .cargo, country: country)
	}

	var nav2: Unit? {
		Unit(model: .destroyer, country: country)
	}

	var nav3: Unit? {
		Unit(model: .cruiser, country: country)
	}
}
