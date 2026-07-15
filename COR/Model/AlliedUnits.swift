extension UnitStats {

	// MARK: Infantry
	@safe nonisolated(unsafe) static let ranger = UnitStats(
		type: .inf,
		tier: 1,
		mov: 3,
		rng: 1,
		ini: 5,
		softAtk: 8,
		hardAtk: 3,
		navAtk: 1,
		groundDef: 7,
		airDef: 4
	)
	@safe nonisolated(unsafe) static let delta = UnitStats(
		type: .inf,
		tier: 3,
		mov: 4,
		rng: 1,
		ini: 9,
		softAtk: 11,
		hardAtk: 5,
		airAtk: 2,
		navAtk: 2,
		groundDef: 9,
		airDef: 8,
		traits: .elite
	)

	// MARK: IFV
	@safe nonisolated(unsafe) static let m2A2 = UnitStats(
		type: .lightTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 9,
		airAtk: 3,
		navAtk: 3,
		groundDef: 10,
		airDef: 7,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let m113 = UnitStats(
		type: .lightTrack,
		mov: 6,
		rng: 1,
		ini: 7,
		softAtk: 7,
		hardAtk: 3,
		airAtk: 2,
		navAtk: 1,
		groundDef: 8,
		airDef: 6,
		traits: .transport
	)

	// MARK: Tanks
	@safe nonisolated(unsafe) static let m48 = UnitStats(
		type: .heavyTrack,
		mov: 5,
		rng: 1,
		ini: 7,
		softAtk: 8,
		hardAtk: 11,
		navAtk: 4,
		groundDef: 11,
		airDef: 6
	)
	@safe nonisolated(unsafe) static let m1A1 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 7,
		rng: 1,
		ini: 8,
		softAtk: 10,
		hardAtk: 13,
		navAtk: 5,
		groundDef: 12,
		airDef: 7
	)
	@safe nonisolated(unsafe) static let m1A2 = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 7,
		rng: 1,
		ini: 9,
		softAtk: 10,
		hardAtk: 15,
		navAtk: 6,
		groundDef: 13,
		airDef: 7,
		traits: .elite
	)

	// MARK: Art
	@safe nonisolated(unsafe) static let m777 = UnitStats(
		type: .art,
		tier: 1,
		mov: 2,
		rng: 3,
		ini: 1,
		softAtk: 11,
		hardAtk: 7,
		navAtk: 4,
		groundDef: 5,
		airDef: 4
	)
	@safe nonisolated(unsafe) static let m270 = UnitStats(
		type: .trackArt,
		tier: 1,
		mov: 5,
		rng: 3,
		ini: 4,
		softAtk: 11,
		hardAtk: 7,
		navAtk: 4,
		groundDef: 5,
		airDef: 4
	)

	// MARK: AA
	@safe nonisolated(unsafe) static let patriot = UnitStats(
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

	// MARK: Air
	@safe nonisolated(unsafe) static let mh6 = UnitStats(
		type: .heli,
		tier: 1,
		mov: 10,
		rng: 1,
		ini: 9,
		softAtk: 8,
		hardAtk: 9,
		airAtk: 9,
		navAtk: 4,
		groundDef: 8,
		airDef: 7,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let f16 = UnitStats(
		type: .fighter,
		tier: 1,
		mov: 12,
		rng: 2,
		ini: 11,
		softAtk: 9,
		hardAtk: 11,
		airAtk: 13,
		navAtk: 8,
		groundDef: 9,
		airDef: 9,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let f35 = UnitStats(
		type: .fighter,
		tier: 2,
		mov: 12,
		rng: 2,
		ini: 12,
		softAtk: 10,
		hardAtk: 13,
		airAtk: 15,
		navAtk: 10,
		groundDef: 11,
		airDef: 11,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let mq9 = UnitStats(
		type: .heli,
		tier: 2,
		mov: 9,
		ini: 5,
		softAtk: 7,
		hardAtk: 9,
		navAtk: 5,
		groundDef: 7,
		airDef: 6,
		traits: .optics
	)
}
