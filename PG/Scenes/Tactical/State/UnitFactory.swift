extension Stats {

	static func inf(_ country: Country) -> Self {
		switch country.team {
		case .axis, .allies: .regular
		case .soviet: .regular
		}
	}

	static func inf2(_ country: Country) -> Self {
		switch country.team {
		case .axis, .allies: .special >< .veteran
		case .soviet: .special
		}
	}

	static func ifv(_ country: Country) -> Self {
		switch country.team {
		case .axis: .boxer
		case .allies, .soviet: .recon
		}
	}

	static func tank(_ country: Country) -> Self {
		switch country {
		case .ned, .swe, .ukr: .strv122
		case .usa, .isr: .m1A2
		case .pak: .m1A1
		case .rus, .irn, .ind: .t72
		}
	}

	static func tank2(_ country: Country) -> Self {
		switch country {
		case .ned, .swe, .ukr: .strv122 >< .veteran
		case .usa, .isr: .m1A2 >< .veteran
		case .pak: .m1A2
		case .rus: .t90m_proryv
		case .irn, .ind: .t72 >< .veteran
		}
	}

	static func art(_ country: Country) -> Self {
		switch country.team {
		case .axis: .pzh
		default: .art105
		}
	}

	static func heli(_ country: Country) -> Self {
		switch country.team {
		default: .mh6
		}
	}

	static func aa(_ country: Country) -> Self {
		switch country.team {
		case .axis: .lvkv90
		default: .neva
		}
	}

	static var base: Self {
		.make { stats in
			stats.hp = 0xF
			stats.mp = 0x1
			stats.ap = 0x1
			stats.ammo = 0x7
		}
	}

	static var veteran: Self {
		.make { stats in stats.exp = 0x10 }
	}

	static var elite: Self {
		.make { stats in stats.exp = 0x20 }
	}

	static var truck: Self {
		.make { stats in
			stats.type = .softWheel
			stats[.supply] = true
			stats[.transport] = true
			stats.mov = 8
			stats.groundDef = 3
			stats.airDef = 1
		}
	}

	static var regular: Self {
		.make { stats in
			stats.type = .soft
			stats.ini = 4
			stats.softAtk = 6
			stats.hardAtk = 2
			stats.groundDef = 6
			stats.airDef = 4
			stats.mov = 3
			stats.rng = 1
		}
	}

	static var special: Self {
		.make { stats in
			stats.type = .soft
			stats[.hardcore] = true
			stats.ini = 7
			stats.softAtk = 8
			stats.hardAtk = 5
			stats.airAtk = 2
			stats.groundDef = 9
			stats.airDef = 8
			stats.mov = 4
			stats.rng = 1
		}
	}

	static var t72: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 7
			stats.softAtk = 9
			stats.hardAtk = 10
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 10
			stats.airDef = 5
		}
	}

	static var t90m_proryv: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 8
			stats.softAtk = 9
			stats.hardAtk = 11
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 11
			stats.airDef = 6
		}
	}

	static var m1A1: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 8
			stats.softAtk = 10
			stats.hardAtk = 11
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 11
			stats.airDef = 6
		}
	}

	static var m1A2: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 9
			stats.softAtk = 10
			stats.hardAtk = 12
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 12
			stats.airDef = 7
		}
	}

	static var strv122: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 9
			stats.softAtk = 9
			stats.hardAtk = 11
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 13
			stats.airDef = 8
		}
	}

	static var boxer: Self {
		.make { stats in
			stats.type = .mediumWheel
			stats[.transport] = true
			stats.ini = 9
			stats.softAtk = 9
			stats.hardAtk = 7
			stats.airAtk = 4
			stats.mov = 8
			stats.rng = 1
			stats.groundDef = 10
			stats.airDef = 7
		}
	}

	static var strf90: Self {
		.make { stats in
			stats.type = .mediumTrack
			stats[.transport] = true
			stats.ini = 9
			stats.softAtk = 9
			stats.hardAtk = 8
			stats.airAtk = 4
			stats.mov = 7
			stats.rng = 1
			stats.groundDef = 11
			stats.airDef = 7
		}
	}

	static var lvkv90: Self {
		.make { stats in
			stats.type = .mediumTrack
			stats[.aa] = true
			stats.ini = 10
			stats.softAtk = 8
			stats.hardAtk = 8
			stats.airAtk = 11
			stats.groundDef = 9
			stats.airDef = 11
			stats.mov = 7
			stats.rng = 1
		}
	}

	static var neva: Self {
		.make { stats in
			stats.type = .softWheel
			stats[.aa] = true
			stats.ini = 10
			stats.softAtk = 0
			stats.hardAtk = 0
			stats.airAtk = 13
			stats.groundDef = 4
			stats.airDef = 9
			stats.mov = 6
			stats.rng = 3
		}
	}

	static var art105: Self {
		.make { stats in
			stats.type = .soft
			stats[.art] = true
			stats.ini = 2
			stats.softAtk = 9
			stats.hardAtk = 5
			stats.groundDef = 4
			stats.airDef = 3
			stats.mov = 1
			stats.rng = 3
		}
	}

	static var pzh: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.art] = true
			stats.ini = 5
			stats.softAtk = 11
			stats.hardAtk = 7
			stats.groundDef = 7
			stats.airDef = 6
			stats.mov = 5
			stats.rng = 3
		}
	}

	static var recon: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.transport] = true
			stats.ini = 9
			stats.softAtk = 6
			stats.hardAtk = 4
			stats.airAtk = 3
			stats.groundDef = 7
			stats.airDef = 8
			stats.mov = 7
			stats.rng = 1
		}
	}

	static var mh6: Self {
		.make { stats in
			stats.type = .air
			stats.ini = 9
			stats.softAtk = 8
			stats.hardAtk = 9
			stats.airAtk = 9
			stats.groundDef = 7
			stats.airDef = 7
			stats.mov = 14
			stats.rng = 1
		}
	}
}

extension [Unit] {

	static func template(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: .zero, stats: .base >< .truck),
			Unit(country: country, position: .zero, stats: .base >< .inf(country)),
			Unit(country: country, position: .zero, stats: .base >< .inf2(country)),
			Unit(country: country, position: .zero, stats: .base >< .ifv(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank2(country)),
			Unit(country: country, position: .zero, stats: .base >< .art(country)),
			Unit(country: country, position: .zero, stats: .base >< .aa(country)),
			Unit(country: country, position: .zero, stats: .base >< .heli(country)),
		]
	}

	static func base(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: XY(0, 0), stats: .base >< .truck),
			Unit(country: country, position: XY(0, 1), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(3, 0), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(2, 1), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(0, 2), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(0, 3), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(1, 0), stats: .base >< .ifv(country) >< .veteran),
			Unit(country: country, position: XY(1, 1), stats: .base >< .art(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .art(country) >< .veteran),
		]
	}

	static func small(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: XY(0, 0), stats: .base >< .truck),
			Unit(country: country, position: XY(0, 1), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(2, 0), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(0, 2), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(1, 0), stats: .base >< .ifv(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .art(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .aa(country) >< .veteran),
		]
	}
}
