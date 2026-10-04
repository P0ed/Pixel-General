import Testing
@testable import COR

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
		let atThreshold = Self.unit(exp: 1 << 15)
		#expect(atThreshold.lvl == 8)
		#expect(atThreshold.subLvl == 0)

		let midway = Self.unit(exp: 1 << 15 | 1 << 13)
		#expect(midway.lvl == 8)
		#expect(midway.subLvl == 2)

		#expect(Self.unit(exp: .max).subLvl == 9)
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

	@Test func allArmedUnitsDeclareNavalAttack() {
		var missing: [UnitModel] = []
		for raw in 0 ..< 256 {
			guard let model = UnitModel(rawValue: UInt8(raw)) else { continue }
			let stats = UnitStats.table[raw]
			if stats.softAtk > 0 || stats.hardAtk > 0, stats.navAtk == 0 {
				missing.append(model)
			}
		}
		#expect(missing.isEmpty, "Armed units missing navAtk: \(missing)")

		let cruiser = Unit(model: .cruiser, country: .ger)
		#expect(Unit(model: .regular, country: .usa).atk(cruiser) > 0)
		#expect(Unit(model: .f35, country: .usa).atk(cruiser) > 0)
		#expect(Unit(model: .patriot, country: .usa).atk(cruiser) == 0)
	}

	@Test func allAttackCapableUnitsDeclareAmmo() {
		var missing: [UnitModel] = []
		for raw in 0 ..< 256 {
			guard let model = UnitModel(rawValue: UInt8(raw)) else { continue }
			let stats = UnitStats.table[raw]
			let armed = stats.softAtk > 0 || stats.hardAtk > 0
				|| stats.airAtk > 0 || stats.navAtk > 0
			if stats.rng > 0, armed, stats.ammo == 0 {
				missing.append(model)
			}
		}
		#expect(missing.isEmpty, "Attack-capable units missing ammo: \(missing)")
	}

	@Test func fortDefendsLikeACity() {
		#expect(Terrain.fort.baseEntrenchment == 3)
		#expect(Terrain.fort.def(.inf) == Terrain.city.def(.inf))
		#expect(Terrain.fort.closeCombat(.heavyTrack) == Terrain.city.closeCombat(.heavyTrack))
	}

	@Test func fortMoveCostsPenalizeWheelsAndTracks() {
		#expect(Terrain.fort.moveCost(Unit(model: .regular, country: .ger)) == 1)
		#expect(Terrain.fort.moveCost(Unit(model: .truck, country: .ger)) == 3)
		#expect(Terrain.fort.moveCost(Unit(model: .leo1, country: .ger)) == 2)
	}
}
