extension Unit {

	static func inf(_ country: Country) -> Self {
		switch country.team {
		case .axis, .allies: .regular
		case .soviet: .militia
		}
	}

	static func inf2(_ country: Country) -> Self {
		switch country {
		case .pak: .regular >< .veteran
		default:
			switch country.team {
			case .axis, .allies: .special >< .veteran
			case .soviet: .regular >< .veteran
			}
		}
	}

	static func ifv(_ country: Country) -> Self {
		switch country.team {
		case .axis: .boxer
		case .allies: .m113
		case .soviet: .bmp
		}
	}

	static func ifv2(_ country: Country) -> Self {
		switch country.team {
		case .axis: .strf90
		case .allies: .m2A2
		case .soviet: .t55
		}
	}

	static func tank(_ country: Country) -> Self {
		switch country {
		case .ned, .den, .swe, .ukr: .leo1
		case .usa, .isr: .m48
		case .pak: .m48
		case .rus: .t72
		case .irn, .ind: .t55
		}
	}

	static func tank2(_ country: Country) -> Self {
		switch country {
		case .ned, .den, .swe, .ukr: .strv122
		case .usa, .isr: .m1A2
		case .pak: .m48 >< .veteran
		case .rus: .t90m_proryv
		case .irn, .ind: .t72
		}
	}

	static func art(_ country: Country) -> Self {
		switch country.team {
		case .axis: .art155
		case .allies: .m777
		case .soviet: .art105
		}
	}

	static func art2(_ country: Country) -> Self {
		switch country.team {
		case .axis: .pzh
		case .allies: .m777 >< .veteran
		case .soviet: .art155
		}
	}

	static func heli(_ country: Country) -> Self {
		switch country.team {
		case .allies, .axis: .mh6
		case .soviet: .mi8
		}
	}

	static func fighter(_ country: Country) -> Self {
		switch country.team {
		case .axis: .gripen
		case .allies: .f16
		case .soviet: .mig
		}
	}

	static func air(_ country: Country) -> Self {
		switch country.team {
		case .axis: .gripen
		case .allies: .f16
		case .soviet: .mi24
		}
	}

	static func aa(_ country: Country) -> Self {
		switch country.team {
		case .axis: .lvkv90
		default: .neva
		}
	}

	static var veteran: Self {
		.make { u in u.exp = 0x10 }
	}

	static var aux: Self {
		.make { u in u[.aux] = true }
	}

	static var truck: Self {
		.make { u in
			u.type = .softWheel
			u[.supply] = true
			u[.transport] = true
			u.groundDef = 3
			u.airDef = 1
		}
	}

	static var militia: Self {
		.make { stats in
			stats.type = .soft
			stats.ini = 3
			stats.softAtk = 5
			stats.hardAtk = 1
			stats.groundDef = 5
			stats.airDef = 3
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
		}
	}

	static var special: Self {
		.make { stats in
			stats.type = .soft
			stats[.elite] = true
			stats[.fast] = true
			stats.ini = 7
			stats.softAtk = 8
			stats.hardAtk = 5
			stats.airAtk = 2
			stats.groundDef = 9
			stats.airDef = 8
		}
	}

	static var t55: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 6
			stats.softAtk = 7
			stats.hardAtk = 10
			stats.groundDef = 9
			stats.airDef = 5
		}
	}

	static var t72: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 7
			stats.softAtk = 9
			stats.hardAtk = 12
			stats.groundDef = 10
			stats.airDef = 5
		}
	}

	static var t90m_proryv: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 8
			stats.softAtk = 9
			stats.hardAtk = 13
			stats.groundDef = 11
			stats.airDef = 6
		}
	}

	static var leo1: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 8
			stats.softAtk = 8
			stats.hardAtk = 11
			stats.groundDef = 10
			stats.airDef = 7
		}
	}

	static var strv122: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats[.elite] = true
			stats.ini = 9
			stats.softAtk = 10
			stats.hardAtk = 14
			stats.groundDef = 13
			stats.airDef = 8
		}
	}

	static var boxer: Self {
		.make { stats in
			stats.type = .lightWheel
			stats[.transport] = true
			stats.ini = 8
			stats.softAtk = 10
			stats.hardAtk = 9
			stats.airAtk = 4
			stats.groundDef = 9
			stats.airDef = 7
		}
	}

	static var strf90: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.transport] = true
			stats.ini = 9
			stats.softAtk = 10
			stats.hardAtk = 9
			stats.airAtk = 4
			stats.groundDef = 11
			stats.airDef = 7
		}
	}

	static var lvkv90: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.aa] = true
			stats[.radar] = true
			stats.ini = 10
			stats.softAtk = 9
			stats.hardAtk = 8
			stats.airAtk = 11
			stats.groundDef = 10
			stats.airDef = 11
		}
	}

	static var mh6: Self {
		.make { stats in
			stats.type = .heli
			stats.ini = 9
			stats.softAtk = 8
			stats.hardAtk = 9
			stats.airAtk = 9
			stats.groundDef = 7
			stats.airDef = 7
		}
	}

	static var gripen: Self {
		.make { stats in
			stats.type = .jet
			stats[.aa] = true
			stats[.radar] = true
			stats[.range] = true
			stats.ini = 12
			stats.softAtk = 9
			stats.hardAtk = 11
			stats.airAtk = 12
			stats.groundDef = 10
			stats.airDef = 11
		}
	}

	static var pzh: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.art] = true
			stats[.range] = true
			stats.ini = 5
			stats.softAtk = 11
			stats.hardAtk = 7
			stats.groundDef = 7
			stats.airDef = 6
		}
	}

	static var art105: Self {
		.make { stats in
			stats.type = .soft
			stats[.art] = true
			stats[.range] = true
			stats.ini = 2
			stats.softAtk = 9
			stats.hardAtk = 5
			stats.groundDef = 4
			stats.airDef = 3
		}
	}

	static var art155: Self {
		.make { stats in
			stats.type = .soft
			stats[.art] = true
			stats[.range] = true
			stats.ini = 2
			stats.softAtk = 11
			stats.hardAtk = 7
			stats.groundDef = 5
			stats.airDef = 4
		}
	}

	static var m777: Self {
		.make { stats in
			stats.type = .soft
			stats[.art] = true
			stats[.range] = true
			stats.ini = 2
			stats.softAtk = 11
			stats.hardAtk = 7
			stats.groundDef = 5
			stats.airDef = 4
		}
	}

	static var neva: Self {
		.make { stats in
			stats.type = .softWheel
			stats[.aa] = true
			stats[.range] = true
			stats.ini = 10
			stats.softAtk = 0
			stats.hardAtk = 0
			stats.airAtk = 13
			stats.groundDef = 4
			stats.airDef = 8
		}
	}

	static var bmp: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.transport] = true
			stats.ini = 8
			stats.softAtk = 8
			stats.hardAtk = 7
			stats.airAtk = 3
			stats.groundDef = 7
			stats.airDef = 6
		}
	}

	static var m48: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats.ini = 7
			stats.softAtk = 8
			stats.hardAtk = 10
			stats.groundDef = 10
			stats.airDef = 6
		}
	}

	static var m1A2: Self {
		.make { stats in
			stats.type = .heavyTrack
			stats[.elite] = true
			stats[.fast] = true
			stats.ini = 9
			stats.softAtk = 10
			stats.hardAtk = 14
			stats.groundDef = 12
			stats.airDef = 7
		}
	}

	static var m2A2: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.transport] = true
			stats.ini = 9
			stats.softAtk = 10
			stats.hardAtk = 9
			stats.airAtk = 4
			stats.groundDef = 10
			stats.airDef = 7
		}
	}

	static var m113: Self {
		.make { stats in
			stats.type = .lightTrack
			stats[.transport] = true
			stats.ini = 7
			stats.softAtk = 7
			stats.hardAtk = 3
			stats.airAtk = 2
			stats.groundDef = 8
			stats.airDef = 6
		}
	}

	static var mi8: Self {
		.make { stats in
			stats.type = .heli
			stats[.transport] = true
			stats.ini = 7
			stats.softAtk = 6
			stats.hardAtk = 3
			stats.airAtk = 2
			stats.groundDef = 6
			stats.airDef = 6
		}
	}

	static var mi24: Self {
		.make { stats in
			stats.type = .heli
			stats.ini = 9
			stats.softAtk = 9
			stats.hardAtk = 9
			stats.airAtk = 7
			stats.groundDef = 8
			stats.airDef = 7
		}
	}

	static var f16: Self {
		.make { stats in
			stats.type = .jet
			stats[.aa] = true
			stats[.radar] = true
			stats[.range] = true
			stats.ini = 11
			stats.softAtk = 9
			stats.hardAtk = 11
			stats.airAtk = 13
			stats.groundDef = 10
			stats.airDef = 10
		}
	}

	static var mig: Self {
		.make { stats in
			stats.type = .jet
			stats[.aa] = true
			stats[.radar] = true
			stats[.range] = true
			stats.ini = 10
			stats.softAtk = 8
			stats.hardAtk = 10
			stats.airAtk = 11
			stats.groundDef = 9
			stats.airDef = 9
		}
	}
}
