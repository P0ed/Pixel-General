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

	@Test func campaignAuxScalesWithFactories() {
		let none: [Unit] = .aux(.ger, army: 0, armor: 0, air: 0, aa: 0)
		let some: [Unit] = .aux(.ger, army: 2, armor: 2, air: 1, aa: 1)
		let full: [Unit] = .aux(.ger, army: 4, armor: 4, air: 4, aa: 4)
		#expect(none.count < some.count)
		#expect(some.count < full.count)
		#expect(full.count == 16, "aux must cap at 16 units")
		#expect(full.allSatisfy { $0[.aux] }, "campaign aux units missing the aux skill")
	}

	@Test func campaignAuxVeteransAtThreeFactories() {
		let green: [Unit] = .aux(.ger, army: 2, armor: 0, air: 0, aa: 0)
		let vets: [Unit] = .aux(.ger, army: 3, armor: 0, air: 0, aa: 0)
		let greenInf = green.filter { $0.type == .inf }
		let vetInf = vets.filter { $0.type == .inf }
		#expect(!greenInf.isEmpty && greenInf.allSatisfy { $0.lvl < 2 })
		#expect(!vetInf.isEmpty && vetInf.allSatisfy { $0.lvl >= 2 })
	}

	@Test func shopFactoriesMaskGatesUnitClasses() {
		let armor: Set<UnitType> = [
			.lightWheel, .lightTrack, .heavyTrack,
			.wheelArt, .trackArt, .wheelAA, .trackAA,
		]
		let all = Shop(country: .ger, tier: 3).units
		let noArmor = Shop(
			country: .ger,
			tier: 3,
			factories: ~(1 << BuildingType.armor.rawValue)
		).units
		#expect(all.contains { armor.contains($0.type) })
		#expect(!noArmor.contains { armor.contains($0.type) }, "armor units not gated")
		#expect(noArmor.contains { $0.type == .inf }, "infantry gated by the armor bit")
		#expect(noArmor.contains { $0.type == .supply }, "supply gated by the armor bit")
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
