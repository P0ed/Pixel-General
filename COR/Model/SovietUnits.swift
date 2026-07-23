extension UnitStats {

	// MARK: Infantry
	@safe nonisolated(unsafe) static let militia = UnitStats(
		type: .inf,
		mov: 3,
		rng: 1,
		ammo: 5,
		ini: 3,
		softAtk: 6,
		hardAtk: 2,
		navAtk: 1,
		groundDef: 5,
		airDef: 3
	)
	@safe nonisolated(unsafe) static let speznas = UnitStats(
		type: .inf,
		tier: 2,
		mov: 4,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 9,
		hardAtk: 4,
		airAtk: 2,
		navAtk: 2,
		groundDef: 8,
		airDef: 7,
		traits: .elite
	)

	// MARK: IFV
	@safe nonisolated(unsafe) static let brdm2 = UnitStats(
		type: .lightWheel,
		mov: 8,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 7,
		hardAtk: 5,
		airAtk: 2,
		navAtk: 2,
		groundDef: 7,
		airDef: 6
	)
	@safe nonisolated(unsafe) static let bmp = UnitStats(
		type: .lightTrack,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 8,
		hardAtk: 7,
		airAtk: 2,
		navAtk: 2,
		groundDef: 7,
		airDef: 6,
		traits: .transport
	)

	// MARK: Tanks
	@safe nonisolated(unsafe) static let t55 = UnitStats(
		type: .heavyTrack,
		mov: 5,
		rng: 1,
		ammo: 6,
		ini: 6,
		softAtk: 7,
		hardAtk: 11,
		navAtk: 4,
		groundDef: 10,
		airDef: 5
	)
	@safe nonisolated(unsafe) static let t72 = UnitStats(
		type: .heavyTrack,
		tier: 1,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 7,
		softAtk: 9,
		hardAtk: 13,
		navAtk: 5,
		groundDef: 11,
		airDef: 5
	)
	@safe nonisolated(unsafe) static let t90m = UnitStats(
		type: .heavyTrack,
		tier: 2,
		mov: 6,
		rng: 1,
		ammo: 6,
		ini: 8,
		softAtk: 9,
		hardAtk: 14,
		navAtk: 6,
		groundDef: 12,
		airDef: 6
	)

	// MARK: Art
	@safe nonisolated(unsafe) static let art105 = UnitStats(
		type: .art,
		mov: 2,
		rng: 2,
		ammo: 6,
		ini: 3,
		softAtk: 9,
		hardAtk: 5,
		navAtk: 3,
		groundDef: 5,
		airDef: 4,
		traits: .cheap
	)

	@safe nonisolated(unsafe) static let sp105 = UnitStats(
		type: .trackArt,
		mov: 5,
		rng: 2,
		ammo: 5,
		ini: 3,
		softAtk: 9,
		hardAtk: 5,
		navAtk: 3,
		groundDef: 5,
		airDef: 4
	)

	// MARK: Anti-Air
	@safe nonisolated(unsafe) static let neva = UnitStats(
		type: .wheelAA,
		mov: 7,
		rng: 3,
		ammo: 3,
		ini: 8,
		airAtk: 12,
		groundDef: 4,
		airDef: 7
	)
	@safe nonisolated(unsafe) static let s300 = UnitStats(
		type: .wheelAA,
		tier: 1,
		mov: 7,
		rng: 3,
		ammo: 3,
		ini: 9,
		airAtk: 13,
		groundDef: 4,
		airDef: 8,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let tunguska = UnitStats(
		type: .trackAA,
		mov: 7,
		rng: 1,
		ammo: 5,
		ini: 8,
		softAtk: 7,
		hardAtk: 7,
		airAtk: 9,
		navAtk: 3,
		groundDef: 8,
		airDef: 8
	)

	// MARK: Air
	@safe nonisolated(unsafe) static let mi8 = UnitStats(
		type: .heli,
		mov: 8,
		rng: 1,
		ammo: 3,
		ini: 6,
		softAtk: 6,
		hardAtk: 4,
		airAtk: 2,
		navAtk: 2,
		groundDef: 6,
		airDef: 6,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let mi24 = UnitStats(
		type: .heli,
		tier: 1,
		mov: 9,
		rng: 1,
		ammo: 3,
		ini: 7,
		softAtk: 9,
		hardAtk: 9,
		airAtk: 7,
		navAtk: 5,
		groundDef: 8,
		airDef: 7,
		traits: .transport
	)
	@safe nonisolated(unsafe) static let orlan = UnitStats(
		type: .heli,
		tier: 2,
		mov: 9,
		ini: 5,
		groundDef: 7,
		airDef: 5,
		traits: .optics
	)
	@safe nonisolated(unsafe) static let mig29 = UnitStats(
		type: .fighter,
		tier: 1,
		mov: 12,
		rng: 2,
		ammo: 2,
		ini: 8,
		softAtk: 7,
		hardAtk: 8,
		airAtk: 10,
		navAtk: 6,
		groundDef: 9,
		airDef: 8,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let su57 = UnitStats(
		type: .fighter,
		tier: 2,
		mov: 12,
		rng: 2,
		ammo: 2,
		ini: 9,
		softAtk: 8,
		hardAtk: 10,
		airAtk: 12,
		navAtk: 9,
		groundDef: 9,
		airDef: 9,
		traits: .radar
	)
	@safe nonisolated(unsafe) static let su27 = UnitStats(
		type: .cas,
		tier: 1,
		mov: 11,
		rng: 2,
		ammo: 3,
		ini: 8,
		softAtk: 9,
		hardAtk: 12,
		airAtk: 7,
		navAtk: 10,
		groundDef: 10,
		airDef: 7,
		traits: .radar
	)
}
