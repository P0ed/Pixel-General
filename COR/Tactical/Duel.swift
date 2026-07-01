/// One attacker-vs-defender duel — the single home of the damage curve.
///
/// The caller supplies the assembled numbers (`atk`/`def` already fold in auras
/// and terrain modifiers, `hp` is the attacker's, `crit`/`evasion` are the two
/// combat skills). Two read-outs sit over the *same* curve:
///
/// - `resolve(&rng)` is what `fire` applies to the sim.
/// - `expected()` is the deterministic mean of `resolve` — the AI's estimate.
///
/// Because both derive from one definition, the AI can never plan against a
/// damage model that disagrees with what the engine actually rolls.
struct Duel {
	let atk: Int8
	let def: Int8
	let hp: UInt8
	let crit: Bool
	let evasion: Bool

	/// The live roll. Verbatim relocation of the curve that used to live inline
	/// in `TacticalSim.fire`. The two-phase roll order — all `rounds` main dice
	/// first, then the per-round crit/evasion dice — is load-bearing: the
	/// multiplayer relay compares `d20` state across peers, so the number and
	/// order of `rng()` calls must not change.
	func resolve(_ rng: inout D20) -> UInt8 {
		let dif = atk - def
		let t1 = max(0, 9 - dif)
		let t2 = max(1, 15 - dif)
		let t3 = max(2, 20 - dif)
		let t4 = max(3, 25 - dif)
		let rounds: UInt8 = (hp + 2) / 3

		let ds = (0 ..< rounds).map { _ in rng() }
		let dmgs = ds.map { d in
			var dmg: UInt8 = d > t4 ? 4 : d > t3 ? 3 : d > t2 ? 2 : d > t1 ? 1 : 0
			if crit, rng() > 16 { dmg *= 2 }
			if evasion, rng() > 16 { dmg = 0 }
			return dmg
		}
		return dmgs.reduce(into: 0, +=)
	}

	/// The mean of `resolve`, in closed form. Per round the damage is
	/// `[d>t1] + [d>t2] + [d>t3] + [d>t4]` over `d ∈ 0…19`, so the expected
	/// per-round damage is `(over(t1)+…+over(t4)) / 20` where `over(t)` counts the
	/// faces above `t`. `crit` doubles a round with p = 3/20 (×1.15); `evasion`
	/// zeroes it with p = 3/20 (×0.85). Computed in `Int` to avoid `Int8` overflow.
	func expected() -> UInt8 {
		let dif = Int(atk) - Int(def)
		let t1 = max(0, 9 - dif)
		let t2 = max(1, 15 - dif)
		let t3 = max(2, 20 - dif)
		let t4 = max(3, 25 - dif)
		func over(_ t: Int) -> Int { max(0, 19 - t) }
		let perRound = over(t1) + over(t2) + over(t3) + over(t4)
		let rounds = (Int(hp) + 2) / 3

		var scaled = rounds * perRound * 500 // mean × 10_000  (perRound / 20)
		if crit { scaled = scaled * 115 / 100 }
		if evasion { scaled = scaled * 85 / 100 }
		return UInt8(clamping: (scaled + 5_000) / 10_000)
	}
}
