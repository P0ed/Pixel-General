extension UnitStats {

	// MARK: Infantry
	static let ksk = UnitStats(
		type: .inf,
		tier: 2,
		mov: 4,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 11,
		hardAtk: 5,
		airAtk: 3,
		navAtk: 2,
		groundDef: 9,
		airDef: 8,
		traits: .elite,
		cost: 270
	)
	static let p1sun = UnitStats(
		type: .inf,
		tier: 2,
		mov: 3,
		rng: 4,
		ammo: 4,
		ini: 5,
		softAtk: 8,
		hardAtk: 11,
		airAtk: 9,
		navAtk: 6,
		groundDef: 6,
		airDef: 6,
		traits: [.noRetaliation],
		cost: 270
	)

	// MARK: IFV
	static let fennek = UnitStats(
		type: .lightWheel,
		mov: 9,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 6,
		hardAtk: 3,
		airAtk: 2,
		navAtk: 1,
		groundDef: 6,
		airDef: 6,
		traits: [.optics],
		cost: 170
	)
	static let boxer = UnitStats(
		type: .lightWheel,
		tier: 1,
		mov: 9,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 4,
		navAtk: 3,
		groundDef: 9,
		airDef: 7,
		traits: .transport,
		cost: 315
	)
	static let marder = UnitStats(
		type: .lightTrack,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 9,
		hardAtk: 8,
		airAtk: 3,
		navAtk: 3,
		groundDef: 10,
		airDef: 7,
		traits: [.transport],
		cost: 240
	)
	static let strf90 = UnitStats(
		type: .lightTrack,
		tier: 2,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 10,
		hardAtk: 11,
		airAtk: 5,
		navAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport,
		cost: 390
	)
	static let cv9035 = UnitStats(
		type: .lightTrack,
		tier: 2,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 11,
		hardAtk: 10,
		airAtk: 5,
		navAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport,
		cost: 390
	)
	static let kf41 = UnitStats(
		type: .lightTrack,
		tier: 2,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 11,
		hardAtk: 10,
		airAtk: 5,
		navAtk: 3,
		groundDef: 12,
		airDef: 8,
		traits: [.transport, .elite],
		cost: 410
	)

	// MARK: Art
	static let pzh = UnitStats(
		type: .trackArt,
		tier: 1,
		mov: 5,
		rng: 3,
		ammo: 5,
		ini: 4,
		softAtk: 11,
		hardAtk: 7,
		navAtk: 6,
		groundDef: 6,
		airDef: 5,
		cost: 330
	)
	static let mars = UnitStats(
		type: .trackArt,
		tier: 1,
		mov: 5,
		rng: 5,
		ammo: 3,
		ini: 3,
		softAtk: 12,
		hardAtk: 12,
		navAtk: 11,
		groundDef: 5,
		airDef: 4,
		traits: [.elite, .noRetaliation],
		cost: 470
	)

	// MARK: Tanks
	static let leo1a5 = UnitStats(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 8,
		hardAtk: 12,
		navAtk: 4,
		groundDef: 11,
		airDef: 7,
		cost: 270
	)
	static let leo2a4 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 9,
		hardAtk: 14,
		navAtk: 5,
		groundDef: 13,
		airDef: 7,
		cost: 390
	)
	static let leo2a7 = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 10,
		hardAtk: 16,
		navAtk: 5,
		groundDef: 14,
		airDef: 8,
		traits: .elite,
		cost: 470
	)
	static let kf51 = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 6,
		rng: 1,
		ammo: 5,
		ini: 9,
		softAtk: 13,
		hardAtk: 17,
		navAtk: 6,
		groundDef: 14,
		airDef: 8,
		traits: .elite,
		cost: 560
	)

	// MARK: AA
	static let bofors = UnitStats(
		type: .aa,
		mov: 2,
		rng: 1,
		ammo: 6,
		ini: 6,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 11,
		navAtk: 3,
		groundDef: 6,
		airDef: 7,
		cost: 193
	)
	static let nasams = UnitStats(
		type: .wheelAA,
		tier: 2,
		mov: 7,
		rng: 3,
		ammo: 4,
		ini: 8,
		airAtk: 14,
		groundDef: 4,
		airDef: 8,
		traits: .radar,
		cost: 312
	)
	static let lvkv90 = UnitStats(
		type: .trackAA,
		tier: 2,
		mov: 7,
		rng: 1,
		ammo: 5,
		ini: 9,
		softAtk: 10,
		hardAtk: 8,
		airAtk: 10,
		navAtk: 3,
		groundDef: 10,
		airDef: 9,
		traits: .radar,
		cost: 399
	)

	// MARK: Air
	static let skeldar = UnitStats(
		type: .heli,
		tier: 1,
		mov: 9,
		ini: 7,
		groundDef: 7,
		airDef: 5,
		traits: [.radar, .optics],
		cost: 240
	)
	static let skeldarm = UnitStats(
		type: .heli,
		tier: 2,
		mov: 8,
		rng: 1,
		ammo: 1,
		ini: 6,
		softAtk: 5,
		hardAtk: 5,
		navAtk: 3,
		groundDef: 7,
		airDef: 5,
		cost: 270
	)
	static let nh90 = UnitStats(
		type: .heli,
		mov: 9,
		rng: 1,
		ammo: 2,
		ini: 6,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 5,
		navAtk: 3,
		groundDef: 7,
		airDef: 6,
		traits: .transport,
		cost: 300
	)
	static let gripen = UnitStats(
		type: .fighter,
		tier: 1,
		mov: 12,
		rng: 2,
		ammo: 2,
		ini: 9,
		softAtk: 9,
		hardAtk: 11,
		airAtk: 12,
		navAtk: 8,
		groundDef: 10,
		airDef: 10,
		traits: .radar,
		cost: 510
	)
	static let su25 = UnitStats(
		type: .cas,
		mov: 11,
		rng: 2,
		ammo: 3,
		ini: 8,
		softAtk: 8,
		hardAtk: 11,
		airAtk: 6,
		navAtk: 9,
		groundDef: 10,
		airDef: 7,
		cost: 300
	)
}
