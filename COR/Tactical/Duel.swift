/// One attacker-vs-defender duel — the single home of the damage curve.
///
/// The caller supplies the assembled numbers (`atk`/`def` already fold in auras
/// and terrain modifiers, `hp` is the attacker's, `crit`/`evasion` are the two
/// combat skills). Two read-outs sit over the *same* curve:
///
/// - `resolve(&rng)` is what `fire` applies to the sim.
/// - `expected()` is the deterministic mean of `resolve` — the AI's estimate.
struct Duel {
	var atk: Int8
	var def: Int8
	var hp: UInt8
	var crit: Bool
	var evasion: Bool

	/// The live roll. The two-phase roll order — all `rounds` main dice
	/// first, then the per-round crit/evasion dice — is load-bearing: the
	/// multiplayer relay compares `d20` state across peers, so the number and
	/// order of `d20()` calls must not change.
	func resolve(_ d20: inout D20) -> UInt8 {
		let ts = thresholds
		let rounds: UInt8 = (hp + 2) / 3

		let ds = (0 ..< rounds).map { _ in d20() }
		let dmgs = ds.map { d in
			var dmg: UInt8 = d > ts[3] ? 4 : d > ts[2] ? 3 : d > ts[1] ? 2 : d > ts[0] ? 1 : 0
			if crit, d20() > 16 { dmg *= 2 }
			if evasion, d20() > 16 { dmg = 0 }
			return dmg
		}
		return dmgs.reduce(into: 0, +=)
	}

	/// The mean of `resolve`, in closed form. Per round the damage is
	/// `[d>ts0] + [d>ts1] + [d>ts2] + [d>ts3]` over `d ∈ 0…19`, so the expected
	/// per-round damage is `(over(ts0)+…+over(ts3)) / 20` where `over(t)` counts the
	/// faces above `t`. `crit` doubles a round with p = 3/20 (×1.15); `evasion`
	/// zeroes it with p = 3/20 (×0.85).
	func expected() -> UInt8 {
		let ts = thresholds
		func over(_ t: Int) -> Int { max(0, 19 - t) }
		let perRound = over(ts[0]) + over(ts[1]) + over(ts[2]) + over(ts[3])
		let rounds = (Int(hp) + 2) / 3

		var scaled = rounds * perRound * 500 // mean × 10_000  (perRound / 20)
		if crit { scaled = scaled * 115 / 100 }
		if evasion { scaled = scaled * 85 / 100 }
		return UInt8(clamping: (scaled + 5_000) / 10_000)
	}

	private var thresholds: [4 of Int] {
		let dif = Int(atk) - Int(def)

		return [
			max(0, 9 - dif),
			max(1, 15 - dif),
			max(2, 20 - dif),
			max(3, 25 - dif),
		]
	}
}
