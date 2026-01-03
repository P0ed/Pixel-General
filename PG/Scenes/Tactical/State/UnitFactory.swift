extension Stats {

	static var base: Self {
		.make { stats in
			stats.hp = 0xF
			stats.mp = 0x1
			stats.ap = 0x1
			stats.ammo = 0xF
		}
	}

	static func ifv(_ country: Country) -> Self {
		switch country.team {
		case .axis: .strf90
		case .allies, .soviet: .recon
		}
	}

	static func tank(_ country: Country) -> Self {
		switch country {
		case .ukr, .swe: .strv122
		case .usa, .isr: .m1A2
		case .rus, .irn, .dnr, .lnr: .t72
		}
	}

	static func tank2(_ country: Country) -> Self {
		switch country {
		case .ukr, .swe: .strv122 >< .veteran
		case .usa, .isr: .m1A2
		case .rus: .t90m_proryv
		case .irn, .dnr, .lnr: .t72 >< .veteran
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

	static var veteran: Self {
		.make { stats in stats.exp = 0x10 }
	}

	static var elite: Self {
		.make { stats in stats.exp = 0x20 }
	}

	static var truck: Self {
		.make { stats in
			stats[.supply] = true
			stats.type = .softWheel
			stats.mov = 8
			stats.groundDef = 3
			stats.airDef = 1
		}
	}

	static var inf: Self {
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

	static var t72: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 7
			stats.softAtk = 9
			stats.hardAtk = 9
			stats.airAtk = 1
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
			stats.hardAtk = 10
			stats.airAtk = 1
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
			stats.softAtk = 9
			stats.hardAtk = 11
			stats.airAtk = 2
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
			stats.hardAtk = 10
			stats.airAtk = 2
			stats.mov = 6
			stats.rng = 1
			stats.groundDef = 13
			stats.airDef = 8
		}
	}

	static var strf90: Self {
		.make { stats in
			stats.type = .mediumTrack
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
			stats.airAtk = 12
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
			stats.airAtk = 14
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
