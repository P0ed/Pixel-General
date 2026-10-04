import Testing
@testable import COR

struct CoreTests {

	private static func battle(units: [Unit] = []) -> TacticalSim {
		var map = Map<32, Terrain>(zero: .field)
		let cities: [(XY, Country)] = [(XY(5, 5), .ger), (XY(26, 26), .usa)]
		for (xy, _) in cities { map[xy] = .city }
		return TacticalSim(
			map: consume map,
			players: [Player(country: .ger), Player(country: .usa, type: .ai)],
			cities: cities,
			units: units
		)
	}

	@Test func scenarioStartsWithStoredHQState() {
		var core = Core.new(country: .ger)
		var hq = clone(core.hq)
		hq.player.prestige = 900
		hq.units[0] = modifying(Unit(model: .leo1, country: .ger)) { $0.reset() }
		core.store(hq)

		let battle = Self.battle(units: [hq.units[0]])
		core.startScenario(battle)
		let stored = clone(core.tactical!)
		let location = core.location
		let prestige = core.hq.player.prestige
		let roster = core.hq.units[0].model
		let deployed = stored.units[0].model

		#expect(location == .tactical)
		#expect(prestige == 900)
		#expect(roster == .leo1)
		#expect(deployed == .leo1)
	}

	@Test func completionReturnsOnlyLivingCoreUnitsAndPrestigeToHQ() {
		let veteran = modifying(Unit(model: .leo1, country: .ger)) { unit in
			unit.reset()
			unit.lvl = 3
			unit.kills = 7
		}
		var battle = Self.battle(units: [
			veteran,
			Unit(model: .regular, country: .ger).aux,
			Unit(model: .regular, country: .ger),
			Unit(model: .leo1, country: .usa),
		])
		battle.units[0].hp = 4
		battle.units[0].ammo = 0
		battle.units[2].hp = 0
		battle[.ger].prestige = 777
		var core = Core.new(country: .ger)
		core.startScenario(battle)
		core.complete(battle)
		let location = core.location
		let hasBattle = core.tactical != nil
		let prestige = core.hq.player.prestige
		let survivors = core.hq.units.compactMap { $0.alive ? $0 : nil }

		#expect(location == .hq)
		#expect(!hasBattle)
		#expect(prestige == 777)
		#expect(survivors.count == 1)
		#expect(survivors.first?.model == .leo1)
		#expect(survivors.first?.lvl == 3)
		#expect(survivors.first?.kills == 7)
		#expect(survivors.first?.hp == veteran.maxHP)
		#expect(survivors.first?.ammo == veteran.maxAmmo)
	}

	@Test func completionKeepsAWipedRosterEmpty() {
		var battle = Self.battle(units: [Unit(model: .regular, country: .ger)])
		battle.units[0].hp = 0
		var core = Core.new(country: .ger)
		core.startScenario(battle)
		core.complete(battle)
		let survivors = core.hq.units.compactMap { $0.alive ? $0 : nil }
		#expect(survivors.isEmpty)
	}

	@Test(arguments: [Location.hq, .tactical])
	func persistenceRestoresHQAndScenarioState(location: Location) {
		var core = Core.new(country: .ger)
		var hq = clone(core.hq)
		hq.player.prestige = 900
		core.store(hq)
		if location == .tactical {
			var battle = Self.battle(units: [Unit(model: .leo1, country: .ger)])
			battle.turn = 6
			core.startScenario(battle)
		}
		guard let restored: Core = decode(encode(core)) else {
			Issue.record("Could not decode saved core")
			return
		}
		let restoredLocation = restored.location
		let country = restored.hq.player.country
		let prestige = restored.hq.player.prestige
		#expect(restoredLocation == location)
		#expect(country == .ger)
		#expect(prestige == 900)
		if location == .tactical {
			let battle = clone(restored.tactical!)
			let turn = battle.turn
			let model = battle.units[0].model
			#expect(turn == 6)
			#expect(model == .leo1)
		} else {
			let hasBattle = restored.tactical != nil
			#expect(!hasBattle)
		}
	}
}
