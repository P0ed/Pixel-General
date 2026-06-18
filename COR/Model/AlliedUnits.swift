extension Unit {

	// MARK: Infantry
	static let delta = Unit(
		type: .inf,
		mov: 4,
		rng: 1,
		ini: 9,
		softAtk: 11,
		hardAtk: 5,
		airAtk: 2,
		groundDef: 9,
		airDef: 8,
		traits: .elite
	)

	// MARK: IFV
	static let m2A2 = Unit(
		type: .lightTrack,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 3,
		groundDef: 10,
		airDef: 7,
		traits: .transport
	)

	static let m113 = Unit(
		type: .lightTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 3,
		airAtk: 2,
		groundDef: 8,
		airDef: 6,
		traits: .transport
	)

	// MARK: Tanks
	static let m48 = Unit(
		type: .heavyTrack,
		mov: 5,
		rng: 1,
		ini: 7,
		softAtk: 8,
		hardAtk: 11,
		groundDef: 11,
		airDef: 6
	)

	static let m1A1 = Unit(
		type: .heavyTrack,
		mov: 7,
		rng: 1,
		ini: 8,
		softAtk: 10,
		hardAtk: 13,
		groundDef: 12,
		airDef: 7
	)

	static let m1A2 = Unit(
		type: .heavyTrack,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 15,
		groundDef: 13,
		airDef: 7,
		traits: .elite
	)

	// MARK: Art
	static let m777 = Unit(
		type: .art,
		mov: 2,
		rng: 3,
		ini: 1,
		softAtk: 11,
		hardAtk: 7,
		groundDef: 5,
		airDef: 4
	)

	static let m270 = Unit(
		type: .trackArt,
		mov: 5,
		rng: 3,
		ini: 4,
		softAtk: 11,
		hardAtk: 7,
		groundDef: 5,
		airDef: 4
	)

	// MARK: AA
	static let patriot = Unit(
		type: .aa,
		mov: 2,
		rng: 3,
		ini: 9,
		airAtk: 14,
		groundDef: 4,
		airDef: 7,
		traits: .radar
	)

	// MARK: Air
	static let mh6 = Unit(
		type: .heli,
		mov: 10,
		rng: 1,
		ini: 9,
		softAtk: 8,
		hardAtk: 9,
		airAtk: 9,
		groundDef: 8,
		airDef: 7,
		traits: .transport
	)

	static let f16 = Unit(
		type: .jet,
		mov: 12,
		rng: 2,
		ini: 11,
		softAtk: 9,
		hardAtk: 11,
		airAtk: 13,
		groundDef: 10,
		airDef: 10,
		traits: .radar
	)

	static let f35 = Unit(
		type: .jet,
		mov: 12,
		rng: 2,
		ini: 12,
		softAtk: 10,
		hardAtk: 13,
		airAtk: 15,
		groundDef: 11,
		airDef: 13,
		traits: .radar
	)

	static let mq9 = Unit(
		type: .heli,
		mov: 9,
		ini: 5,
		softAtk: 7,
		hardAtk: 9,
		groundDef: 7,
		airDef: 6
	)
}
