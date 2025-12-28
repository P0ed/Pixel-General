extension Stats {

	static var base: Self {
		.make { stats in
			stats.hp = 0xF
			stats.mp = 0x1
			stats.ap = 0x1
			stats.ammo = 0xF
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
			stats.unitType = .support
			stats.moveType = .wheel
			stats.mov = 8
			stats.groundDef = 3
			stats.airDef = 1
		}
	}

	static var inf: Self {
		.make { stats in
			stats.unitType = .fighter
			stats.ini = 4
			stats.softAtk = 6
			stats.hardAtk = 2
			stats.groundDef = 6
			stats.airDef = 4
			stats.mov = 3
			stats.rng = 1
			stats.moveType = .leg
		}
	}

	static var t72: Self {
		.make { stats in
			stats.unitType = .fighter
			stats.moveType = .track
			stats.targetType = .heavy
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

	static var m1A2: Self {
		.make { stats in
			stats.unitType = .fighter
			stats.moveType = .track
			stats.targetType = .heavy
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
			stats.unitType = .fighter
			stats.moveType = .track
			stats.targetType = .heavy
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
			stats.unitType = .fighter
			stats.moveType = .track
			stats.targetType = .light
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
			stats.unitType = .aa
			stats.moveType = .track
			stats.targetType = .light
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

	static var art: Self {
		.make { stats in
			stats.unitType = .art
			stats.moveType = .leg
			stats.ini = 2
			stats.softAtk = 9
			stats.hardAtk = 5
			stats.groundDef = 4
			stats.airDef = 3
			stats.mov = 1
			stats.rng = 3
		}
	}

	static var recon: Self {
		.make { stats in
			stats.unitType = .fighter
			stats.moveType = .track
			stats.targetType = .light
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

	static var mh6: Self {
		.make { stats in
			stats.unitType = .fighter
			stats.moveType = .air
			stats.targetType = .air
			stats.ini = 9
			stats.softAtk = 8
			stats.hardAtk = 9
			stats.airAtk = 9
			stats.groundDef = 7
			stats.airDef = 7
			stats.mov = 9
			stats.rng = 1
		}
	}

	static func heli(_ country: Country) -> Self {
		switch country.team {
		default: .mh6
		}
	}

	static func aa(_ country: Country) -> Self {
		switch country.team {
		default: .lvkv90
		}
	}
}
