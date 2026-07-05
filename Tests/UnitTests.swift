import Testing
@testable import COR

/// `Unit.lvl`/`subLvl` derive both values from the packed `exp` field. `subLvl`
/// used to compute an out-of-range bit shift at the max level (8), which then
/// underflowed and trapped — crashing anywhere the unit's status is displayed.
struct UnitTests {

	private static func unit(exp: UInt16) -> Unit {
		modifying(Unit(model: .leo1, country: .ger)) { u in u.exp = exp }
	}

	@Test func subLvlAtMaxExpDoesNotCrash() {
		let u = Self.unit(exp: .max)
		#expect(u.lvl == 8)
		#expect(u.subLvl == 9)
	}

	@Test func subLvlProgressesThroughMaxLevel() {
		// Just past the level-8 threshold (exp == 1 << 15) subLvl restarts at 0,
		// then climbs gradually up to 9 as exp approaches UInt16.max, instead of
		// jumping straight to 9.
		let atThreshold = Self.unit(exp: 1 << 15)
		#expect(atThreshold.lvl == 8)
		#expect(atThreshold.subLvl == 0)

		let midway = Self.unit(exp: 1 << 15 | 1 << 13) // zero + 8192, req 32768
		#expect(midway.lvl == 8)
		#expect(midway.subLvl == 2)

		#expect(Self.unit(exp: .max - 1).subLvl == 9)
	}

	@Test func subLvlResetsAtEachLevelUp() {
		for lvl: UInt8 in 1...8 {
			let atLevel = modifying(Unit(model: .leo1, country: .ger)) { u in u.lvl = lvl }
			#expect(atLevel.subLvl == 0, "level \(lvl) should start at subLvl 0")
		}
	}

	@Test func subLvlNeverExceedsNine() {
		for exp: UInt16 in stride(from: 0, through: UInt16.max, by: 4001) {
			#expect(Self.unit(exp: exp).subLvl <= 9)
		}
	}
}
