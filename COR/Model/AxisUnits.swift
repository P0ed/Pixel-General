extension Unit {

	// MARK: Infantry
	static let ksk = Unit(
		model: .ksk,
		type: .inf,
		tier: 3,
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
		model: .fennek,
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ini: 7,
		softAtk: 6,
		hardAtk: 3,
		airAtk: 2,
		groundDef: 6,
		airDef: 6,
		traits: .optics
	)

	static let boxer = Unit(
		model: .boxer,
		type: .lightWheel,
		tier: 1,
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
		model: .strf90,
		type: .lightTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 10,
		airAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport
	)

	static let kf41 = Unit(
		model: .kf41,
		type: .lightTrack,
		tier: 1,
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

	static let cv9035 = Unit(
		model: .cv9035,
		type: .lightTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 10,
		airAtk: 4,
		groundDef: 11,
		airDef: 8,
		traits: .transport
	)

	// MARK: Art
	static let pzh = Unit(
		model: .pzh,
		type: .trackArt,
		tier: 1,
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
		model: .leo1,
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 8,
		softAtk: 8,
		hardAtk: 12,
		groundDef: 11,
		airDef: 7
	)

	static let strv103 = Unit(
		model: .strv103,
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 13,
		groundDef: 11,
		airDef: 7
	)

	static let strv122 = Unit(
		model: .strv122,
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 15,
		groundDef: 14,
		airDef: 8,
		traits: .elite
	)

	static let kf51 = Unit(
		model: .kf51,
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ini: 10,
		softAtk: 12,
		hardAtk: 16,
		groundDef: 14,
		airDef: 8,
		traits: .elite
	)

	static let leo2a6 = Unit(
		model: .leo2a6,
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 15,
		groundDef: 13,
		airDef: 8,
		traits: .elite
	)

	// MARK: AA
	static let bofors = Unit(
		model: .bofors,
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
		model: .nasams,
		type: .aa,
		tier: 1,
		mov: 2,
		rng: 3,
		ini: 9,
		airAtk: 14,
		groundDef: 4,
		airDef: 7,
		traits: .radar
	)

	static let lvkv90 = Unit(
		model: .lvkv90,
		type: .trackAA,
		tier: 1,
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
		model: .skeldar,
		type: .heli,
		tier: 1,
		mov: 9,
		ini: 6,
		groundDef: 7,
		airDef: 6,
		traits: [.radar, .optics]
	)

	static let skeldarm = Unit(
		model: .skeldarm,
		type: .heli,
		tier: 2,
		mov: 8,
		ini: 6,
		softAtk: 5,
		hardAtk: 5,
		groundDef: 7,
		airDef: 6
	)

	static let nh90 = Unit(
		model: .nh90,
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
		model: .gripen,
		type: .fighter,
		tier: 1,
		mov: 12,
		rng: 2,
		ini: 12,
		softAtk: 9,
		hardAtk: 11,
		airAtk: 12,
		groundDef: 10,
		airDef: 10,
		traits: .radar
	)
}
