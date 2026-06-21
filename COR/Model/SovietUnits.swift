extension UnitStats {

	// MARK: Infantry
	static let militia = UnitStats(
		type: .inf,
		mov: 3,
		rng: 1,
		ini: 3,
		softAtk: 5,
		hardAtk: 1,
		groundDef: 5,
		airDef: 3
	)
	static let speznas = UnitStats(
		type: .inf,
		tier: 2,
		mov: 4,
		rng: 1,
		ini: 8,
		softAtk: 9,
		hardAtk: 4,
		airAtk: 2,
		groundDef: 8,
		airDef: 7,
		traits: .elite
	)

	// MARK: IFV
	static let brdm2 = UnitStats(
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 5,
		airAtk: 2,
		groundDef: 7,
		airDef: 6
	)
	static let bmp = UnitStats(
		type: .lightTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 8,
		hardAtk: 7,
		airAtk: 2,
		groundDef: 7,
		airDef: 6,
		traits: .transport
	)

	// MARK: Tanks
	static let t55 = UnitStats(
		type: .heavyTrack,
		mov: 5,
		rng: 1,
		ini: 6,
		softAtk: 7,
		hardAtk: 11,
		groundDef: 10,
		airDef: 5
	)
	static let t72 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 9,
		hardAtk: 13,
		groundDef: 11,
		airDef: 5
	)
	static let t90m = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 6,
		rng: 1,
		ini: 8,
		softAtk: 9,
		hardAtk: 14,
		groundDef: 12,
		airDef: 6
	)

	// MARK: Art
	static let art105 = UnitStats(
		type: .art,
		mov: 2,
		rng: 2,
		ini: 1,
		softAtk: 9,
		hardAtk: 5,
		groundDef: 5,
		airDef: 4
	)

	// MARK: Anti-Air
	static let neva = UnitStats(
		type: .wheelAA,
		mov: 7,
		rng: 3,
		ini: 8,
		airAtk: 12,
		groundDef: 4,
		airDef: 7
	)
	static let s300 = UnitStats(
		type: .wheelAA,
		tier: 1,
		mov: 7,
		rng: 3,
		ini: 9,
		airAtk: 13,
		groundDef: 4,
		airDef: 8,
		traits: .radar
	)
	static let tunguska = UnitStats(
		type: .trackAA,
		mov: 7,
		rng: 1,
		ini: 8,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 9,
		groundDef: 8,
		airDef: 8
	)

	// MARK: Air
	static let mi8 = UnitStats(
		type: .heli,
		mov: 8,
		rng: 1,
		ini: 7,
		softAtk: 6,
		hardAtk: 4,
		airAtk: 2,
		groundDef: 6,
		airDef: 6,
		traits: .transport
	)
	static let mi24 = UnitStats(
		type: .heli,
		tier: 1,
		mov: 9,
		rng: 1,
		ini: 8,
		softAtk: 9,
		hardAtk: 9,
		airAtk: 7,
		groundDef: 8,
		airDef: 7,
		traits: .transport
	)
	static let orlan = UnitStats(
		type: .heli,
		tier: 2,
		mov: 9,
		ini: 5,
		groundDef: 7,
		airDef: 5,
		traits: .optics
	)
	static let mig29 = UnitStats(
		type: .fighter,
		tier: 1,
		mov: 12,
		rng: 2,
		ini: 8,
		softAtk: 7,
		hardAtk: 8,
		airAtk: 10,
		groundDef: 9,
		airDef: 8,
		traits: .radar
	)
	static let su57 = UnitStats(
		type: .fighter,
		tier: 2,
		mov: 12,
		rng: 2,
		ini: 9,
		softAtk: 8,
		hardAtk: 10,
		airAtk: 12,
		groundDef: 9,
		airDef: 9,
		traits: .radar
	)
	static let su27 = UnitStats(
		type: .cas,
		tier: 1,
		mov: 11,
		rng: 2,
		ini: 10,
		softAtk: 9,
		hardAtk: 12,
		airAtk: 7,
		groundDef: 10,
		airDef: 7,
		traits: .radar
	)
}
