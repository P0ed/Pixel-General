extension UnitStats {

	// MARK: Infantry
	@safe nonisolated(unsafe) static let ksk = UnitStats(
		type: .inf,
		tier: 2,
		mov: 4,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 10,
		hardAtk: 5,
		airAtk: 3,
		navAtk: 2,
		groundDef: 9,
		airDef: 8,
		traits: .elite
	)

	// MARK: IFV
	@safe nonisolated(unsafe) static let fennek = UnitStats(
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 6,
		hardAtk: 3,
		airAtk: 2,
		navAtk: 1,
		groundDef: 6,
		airDef: 6,
		traits: .optics
	)
	@safe nonisolated(unsafe) static let boxer = UnitStats(
		type: .lightWheel,
		tier: 1,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 4,
		navAtk: 3,
		groundDef: 9,
		airDef: 7,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let strf90 = UnitStats(
		type: .lightTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 10,
		hardAtk: 10,
		airAtk: 4,
		navAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let strf90v = UnitStats(
		type: .lightTrack,
		tier: 2,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 11,
		hardAtk: 11,
		airAtk: 5,
		navAtk: 4,
		groundDef: 12,
		airDef: 8,
		traits: [.transport, .elite]
	)
	@safe nonisolated(unsafe) static let kf41 = UnitStats(
		type: .lightTrack,
		tier: 2,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 11,
		hardAtk: 10,
		airAtk: 5,
		navAtk: 4,
		groundDef: 12,
		airDef: 8,
		traits: [.transport, .elite]
	)
	@safe nonisolated(unsafe) static let cv9035 = UnitStats(
		type: .lightTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 10,
		hardAtk: 10,
		airAtk: 4,
		navAtk: 3,
		groundDef: 11,
		airDef: 8,
		traits: .transport
	)

	// MARK: Art
	@safe nonisolated(unsafe) static let pzh = UnitStats(
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
		airDef: 5
	)
	@safe nonisolated(unsafe) static let mars = UnitStats(
		type: .trackArt,
		tier: 1,
		mov: 5,
		rng: 5,
		ammo: 3,
		ini: 3,
		softAtk: 12,
		hardAtk: 9,
		navAtk: 10,
		groundDef: 5,
		airDef: 4,
		traits: [.elite, .noRetaliation]
	)

	// MARK: Tanks
	@safe nonisolated(unsafe) static let leo1 = UnitStats(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 8,
		hardAtk: 12,
		navAtk: 4,
		groundDef: 11,
		airDef: 7
	)
	@safe nonisolated(unsafe) static let leo2a6 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 10,
		hardAtk: 15,
		navAtk: 5,
		groundDef: 13,
		airDef: 8,
		traits: .elite
	)
	@safe nonisolated(unsafe) static let strv103 = UnitStats(
		type: .heavyTrack,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 6,
		softAtk: 7,
		hardAtk: 13,
		navAtk: 4,
		groundDef: 11,
		airDef: 7
	)
	@safe nonisolated(unsafe) static let strv122 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 9,
		softAtk: 10,
		hardAtk: 15,
		navAtk: 5,
		groundDef: 14,
		airDef: 8,
		traits: .elite
	)
	@safe nonisolated(unsafe) static let kf51 = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 6,
		rng: 1,
		ammo: 5,
		ini: 9,
		softAtk: 12,
		hardAtk: 16,
		navAtk: 6,
		groundDef: 14,
		airDef: 8,
		traits: .elite
	)

	// MARK: AA
	@safe nonisolated(unsafe) static let bofors = UnitStats(
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
		airDef: 7
	)
	@safe nonisolated(unsafe) static let nasams = UnitStats(
		type: .wheelAA,
		tier: 1,
		mov: 7,
		rng: 3,
		ammo: 4,
		ini: 8,
		airAtk: 14,
		groundDef: 4,
		airDef: 8,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let lvkv90 = UnitStats(
		type: .trackAA,
		tier: 1,
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
		traits: .radar
	)
	@safe nonisolated(unsafe) static let p1sun = UnitStats(
		type: .aa,
		tier: 2,
		mov: 3,
		rng: 3,
		ammo: 4,
		ini: 5,
		airAtk: 9,
		groundDef: 6,
		airDef: 5,
		traits: [.noRetaliation]
	)

	// MARK: Air
	@safe nonisolated(unsafe) static let skeldar = UnitStats(
		type: .heli,
		tier: 2,
		mov: 9,
		ini: 7,
		groundDef: 7,
		airDef: 5,
		traits: [.radar, .optics]
	)
	@safe nonisolated(unsafe) static let skeldarm = UnitStats(
		type: .heli,
		tier: 3,
		mov: 8,
		rng: 1,
		ammo: 1,
		ini: 6,
		softAtk: 5,
		hardAtk: 5,
		navAtk: 3,
		groundDef: 7,
		airDef: 5
	)
	@safe nonisolated(unsafe) static let nh90 = UnitStats(
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
		traits: .transport
	)
	@safe nonisolated(unsafe) static let gripen = UnitStats(
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
		traits: .radar
	)
	@safe nonisolated(unsafe) static let su25 = UnitStats(
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
		airDef: 7
	)
}
