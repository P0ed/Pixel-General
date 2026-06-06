extension Unit {

	// MARK: Infantry
	static let ksk = Unit(
		type: .inf,
		mov: 4,
		rng: 1,
		ini: 10,
		softAtk: 10,
		hardAtk: 5,
		airAtk: 3,
		groundDef: 9,
		airDef: 8,
		traits: .elite
	)

	// MARK: IFV
	static let fennek = Unit(
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ini: 7,
		softAtk: 5,
		hardAtk: 3,
		airAtk: 2,
		groundDef: 6,
		airDef: 6,
		traits: .radar
	)

	static let boxer = Unit(
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ini: 8,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 3,
		groundDef: 9,
		airDef: 7,
		traits: .transport
	)

	static let strf90 = Unit(
		type: .lightTrack,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport
	)

	static let kf41 = Unit(
		type: .lightTrack,
		mov: 7,
		rng: 1,
		ini: 10,
		softAtk: 11,
		hardAtk: 10,
		airAtk: 5,
		groundDef: 12,
		airDef: 8,
		traits: .elite
	)

	// MARK: Art
	static let pzh = Unit(
		type: .trackArt,
		mov: 5,
		rng: 3,
		ini: 4,
		softAtk: 11,
		hardAtk: 7,
		groundDef: 6,
		airDef: 5
	)

	// MARK: Tanks
	static let leo1 = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 8,
		softAtk: 8,
		hardAtk: 11,
		groundDef: 10,
		airDef: 7
	)

	static let strv103 = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 12,
		groundDef: 10,
		airDef: 7
	)

	static let strv122 = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 14,
		groundDef: 13,
		airDef: 8,
		traits: .elite
	)

	static let kf51 = Unit(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 10,
		softAtk: 12,
		hardAtk: 15,
		groundDef: 14,
		airDef: 8,
		traits: .elite
	)

	// MARK: AA
	static let bofors = Unit(
		type: .aa,
		mov: 2,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 11,
		groundDef: 6,
		airDef: 7
	)

	static let nasams = Unit(
		type: .aa,
		mov: 2,
		rng: 3,
		ini: 9,
		airAtk: 14,
		groundDef: 4,
		airDef: 7,
		traits: .radar
	)

	static let lvkv90 = Unit(
		type: .trackAA,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 9,
		hardAtk: 8,
		airAtk: 10,
		groundDef: 10,
		airDef: 9,
		traits: .radar
	)

	// MARK: Air
	static let skeldar = Unit(
		type: .heli,
		mov: 9,
		ini: 6,
		groundDef: 7,
		airDef: 6,
		traits: .radar
	)

	static let skeldarm = Unit(
		type: .heli,
		mov: 8,
		ini: 6,
		softAtk: 5,
		hardAtk: 5,
		groundDef: 7,
		airDef: 6
	)

	static let nh90 = Unit(
		type: .heli,
		mov: 9,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 5,
		groundDef: 7,
		airDef: 6,
		traits: .transport
	)

	static let gripen = Unit(
		type: .jet,
		mov: 12,
		rng: 2,
		ini: 12,
		softAtk: 9,
		hardAtk: 11,
		airAtk: 12,
		groundDef: 10,
		airDef: 11,
		traits: .radar
	)
}
