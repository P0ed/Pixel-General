extension Unit {

	// MARK: Infantry
	static let militia = Unit(
		type: .inf,
		mov: 3,
		rng: 1,
		ini: 3,
		softAtk: 5,
		hardAtk: 1,
		groundDef: 5,
		airDef: 3
	)

	static let speznas = Unit(
		type: .inf,
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
	static let brdm2 = Unit(
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

	static let bmp = Unit(
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
	static let t55 = Unit(
		type: .heavyTrack,
		mov: 5,
		rng: 1,
		ini: 6,
		softAtk: 7,
		hardAtk: 10,
		groundDef: 9,
		airDef: 5
	)
	
	static let t72 = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 9,
		hardAtk: 12,
		groundDef: 10,
		airDef: 5
	)
	
	static let t90m = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 8,
		softAtk: 9,
		hardAtk: 13,
		groundDef: 11,
		airDef: 6
	)

	// MARK: Art
	static let art105 = Unit(
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
	static let neva = Unit(
		type: .wheelAA,
		mov: 7,
		rng: 3,
		ini: 9,
		airAtk: 13,
		groundDef: 4,
		airDef: 7
	)

	static let tunguska = Unit(
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
	static let mi8 = Unit(
		type: .heli,
		mov: 9,
		rng: 1,
		ini: 7,
		softAtk: 6,
		hardAtk: 4,
		airAtk: 2,
		groundDef: 6,
		airDef: 6,
		traits: .transport
	)

	static let mi24 = Unit(
		type: .heli,
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

	static let mig = Unit(
		type: .jet,
		mov: 12,
		rng: 2,
		ini: 10,
		softAtk: 8,
		hardAtk: 10,
		airAtk: 11,
		groundDef: 9,
		airDef: 9,
		traits: .radar
	)

	static let orlan = Unit(
		type: .heli,
		mov: 9,
		ini: 5,
		groundDef: 7,
		airDef: 6
	)
}
