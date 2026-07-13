import Testing
import Foundation
@testable import COR

/// Phase-1 campaign layer: the European map factory, province adjacency/attack
/// rules, the annex-on-win flip, and serialization of the strategic state.
///
/// `StrategicSim` is noncopyable, so every value read by `#expect` is hoisted
/// into a local first — the macro captures its expression and would otherwise
/// require `Copyable`.
@MainActor
struct StrategicTests {

	/// Finds an enemy `target`-owned tile that borders a `human`-owned tile —
	/// i.e. a valid attack target.
	private static func borderTile(
		_ sim: borrowing StrategicSim,
		human: Country,
		target: Country
	) -> XY? {
		for xy in sim.owner.indices where sim.owner[xy] == target {
			let n8 = xy.n8
			for i in 0 ..< n8.count {
				let n = n8[i]
				if sim.owner.contains(n), sim.owner[n] == human {
					return xy
				}
			}
		}
		return nil
	}

	/// Finds a `target`-owned tile `.n4`-adjacent to a human tile and parks
	/// the main army on the human side, making the tile attackable.
	private static func stageAttack(
		_ sim: inout StrategicSim,
		target: Country = .rus
	) -> XY? {
		for xy in sim.owner.indices where sim.owner[xy] == target {
			let n4 = xy.n4
			for i in 0 ..< n4.count {
				let n = n4[i]
				if sim.owner.contains(n), sim.owner[n] == sim.player.country {
					sim.armies[Int(sim.player.country.rawValue)][0].position = n
					sim.armies[Int(sim.player.country.rawValue)][0].mp = Army.moveSpeed
					return xy
				}
			}
		}
		return nil
	}

	private static func infantry(_ country: Country) -> COR.Unit {
		modifying(COR.Unit(model: .regular, country: country)) { unit in unit.reset() }
	}

	private static func borderSim(russianUnits: Int) -> StrategicSim {
		var owner = Map<32, Country>(size: 32, zero: .none)
		owner[XY(1, 1)] = .fin
		owner[XY(2, 1)] = .rus
		var sim = StrategicSim(
			owner: owner,
			player: Player(country: .fin, type: .human)
		)
		let fin = Int(Country.fin.rawValue)
		let rus = Int(Country.rus.rawValue)
		sim.armies[fin][0].active = true
		sim.armies[fin][0].position = XY(1, 1)
		sim.armies[fin][0].mp = Army.moveSpeed
		sim.armies[fin][0].units[0] = infantry(.fin)
		sim.armies[rus][0].active = true
		sim.armies[rus][0].position = XY(2, 1)
		sim.armies[rus][0].mp = Army.moveSpeed
		for index in 0 ..< russianUnits {
			sim.armies[rus][0].units[index] = infantry(.rus)
		}
		return sim
	}

	@Test func europeFactoryParsesMap() {
		let sim = StrategicSim.europe(country: .fin)
		let size = sim.owner.size
		let human = sim.player.country
		let inBattle = sim.battle != nil
		#expect(size == 32)
		#expect(human == .fin)
		#expect(!inBattle)

		var fin = 0, rus = 0, sea = 0
		for xy in sim.owner.indices {
			switch sim.owner[xy] {
			case .fin: fin += 1
			case .rus: rus += 1
			case .none: sea += 1
			default: break
			}
		}
		#expect(fin > 0, "Finland missing from the map")
		#expect(rus > 0, "Russia missing from the map")
		#expect(sea > 0, "water tiles missing from the map")
	}

	@Test func europeTerrainHasHillsAndMountains() {
		let sim = StrategicSim.europe(country: .fin)
		var hills = 0, mountains = 0, highgroundOnSea = 0
		for xy in sim.terrain.indices {
			switch sim.terrain[xy] {
			case .hill: hills += 1
			case .mountain: mountains += 1
			default: continue
			}
			if sim.owner[xy] == .none { highgroundOnSea += 1 }
		}
		#expect(hills > 0, "no hills on the europe map")
		#expect(mountains > 0, "no mountains on the europe map")
		#expect(highgroundOnSea == 0, "elevation placed on sea tiles")

		// The Alps: every Austrian province is hill or mountain.
		var flatAustria = 0
		for xy in sim.owner.indices where sim.owner[xy] == .aut {
			if !sim.terrain[xy].isHighground { flatAustria += 1 }
		}
		#expect(flatAustria == 0, "\(flatAustria) Austrian tiles missed the Alps")
	}

	@Test func cannotAttackOwnOrSea() {
		let sim = StrategicSim.europe(country: .fin)
		var ownTile: XY?
		var seaTile: XY?
		for xy in sim.owner.indices {
			if sim.owner[xy] == .fin, ownTile == nil { ownTile = xy }
			if sim.owner[xy] == .none, seaTile == nil { seaTile = xy }
		}
		if let ownTile {
			let attackable = sim.canAttack(ownTile)
			#expect(!attackable, "own tile is attackable")
		}
		if let seaTile {
			let attackable = sim.canAttack(seaTile)
			#expect(!attackable, "sea tile is attackable")
		}
	}

	@Test func resolveBattleAnnexesOnWin() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.borderTile(sim, human: .fin, target: .rus) else {
			Issue.record("no border tile to contest")
			return
		}
		sim.battle = target
		sim.resolveBattle(at: target, won: true, by: .fin)
		let owner = sim.owner[target]
		let inBattle = sim.battle != nil
		#expect(owner == .fin, "won battle did not annex the tile")
		#expect(!inBattle, "battle context not cleared")
	}

	@Test func resolveBattleKeepsTileOnLoss() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.borderTile(sim, human: .fin, target: .rus) else {
			Issue.record("no border tile to contest")
			return
		}
		sim.battle = target
		sim.resolveBattle(at: target, won: false, by: .fin)
		let owner = sim.owner[target]
		let inBattle = sim.battle != nil
		#expect(owner == .rus, "repulse should not flip the tile")
		#expect(!inBattle, "battle context not cleared")
	}

	@Test func resolveBattleDoesNotFloodSea() {
		var sim = StrategicSim.europe(country: .fin)
		// Pick a sea tile so the capture radius certainly overlaps water.
		var seaTile: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .none {
			seaTile = xy
			break
		}
		guard let seaTile else { return }
		sim.resolveBattle(at: seaTile, won: true, by: .fin)
		let owner = sim.owner[seaTile]
		#expect(owner == .none, "sea was converted to land")
	}

	@Test func reduceEndTurnAdvancesDay() {
		var sim = StrategicSim.europe(country: .fin)
		let day = sim.turn
		let events = sim.reduce(.endTurn)
		let turn = sim.turn
		#expect(turn == day + 1)
		#expect(events.count == 1)
		if case .endTurn = events.first {
			// The event persists the reducer mutation even when upkeep is zero.
		} else {
			Issue.record("expected an .endTurn event")
		}
	}

	@Test func europeFactoryPlacementIsDeterministic() {
		let a = StrategicSim.europe(country: .fin)
		let b = StrategicSim.europe(country: .fin)
		// Compare the padding-free maps, not the whole sim — `encode` is a raw
		// memory copy and struct padding bytes differ between allocations.
		let bytesA = (encode(a.owner), encode(a.provinces))
		let bytesB = (encode(b.owner), encode(b.provinces))
		#expect(bytesA == bytesB, "europe() is not byte-identical across calls")

		for c in [Country.ger, .rus, .pol] {
			let civil = a.buildingsTotal(.civil, of: c)
			var military = 0
			for t in [BuildingType.army, .armor, .aa, .air, .uav, .navy] {
				military += a.buildingsTotal(t, of: c)
			}
			#expect(civil >= 1, "\(c) has no civil factory")
			#expect(military >= 1, "\(c) has no military factory")
		}

		var overCap = 0
		for xy in a.provinces.indices {
			for t in BuildingType.allCases where a.provinces[xy][t] > 3 {
				overCap += 1
			}
		}
		#expect(overCap == 0, "factory level above 3")
	}

	@Test func canBuildOnOwnedLandBelowCap() {
		var sim = StrategicSim.europe(country: .fin)
		var own: XY?, enemy: XY?, sea: XY?
		for xy in sim.owner.indices {
			switch sim.owner[xy] {
			case .fin: own = own ?? xy
			case .rus: enemy = enemy ?? xy
			case .none: sea = sea ?? xy
			default: break
			}
		}
		guard let own, let enemy, let sea else {
			Issue.record("europe map is missing a tile class")
			return
		}
		let buildOwn = sim.canBuild(.fort, at: own)
		let buildEnemy = sim.canBuild(.fort, at: enemy)
		let buildSea = sim.canBuild(.fort, at: sea)
		#expect(buildOwn, "own land tile should be fortifiable")
		#expect(!buildEnemy, "enemy tile is fortifiable")
		#expect(!buildSea, "sea tile is fortifiable")

		sim.provinces[own][.fort] = 3
		let capped = sim.canBuild(.fort, at: own)
		#expect(!capped, "fort level 3 should cap building")

		sim.provinces[own][.fort] = 0
		sim.battle = enemy
		let duringBattle = sim.canBuild(.fort, at: own)
		#expect(!duringBattle, "building allowed while a battle is running")
	}

	@Test func reduceBuildRaisesFort() {
		var sim = StrategicSim.europe(country: .fin)
		var own: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .fin {
			own = xy
			break
		}
		guard let own else {
			Issue.record("no Finnish tile on the europe map")
			return
		}
		let level = sim.provinces[own][.fort]
		let events = sim.reduce(.build(.fort, at: own))
		let raised = sim.provinces[own][.fort]
		#expect(events.count == 1)
		if case .build(let xy) = events.first {
			#expect(xy == own)
		} else {
			Issue.record("expected a .build event")
		}
		#expect(raised == level + 1, "reduce(.build) should raise the fort")

		var denied: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .rus {
			denied = xy
			break
		}
		if let denied {
			let before = encode(sim)
			let events = sim.reduce(.build(.fort, at: denied))
			let after = encode(sim)
			#expect(events.isEmpty, "building on enemy land emitted an event")
			#expect(before == after, "denied build mutated the sim")
		}
	}

	@Test func buildingsTotalFollowsAnnexation() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.borderTile(sim, human: .fin, target: .rus) else {
			Issue.record("no border tile to contest")
			return
		}
		sim.provinces[target][.army] = 2
		let finBefore = sim.buildingsTotal(.army, of: .fin)
		let rusBefore = sim.buildingsTotal(.army, of: .rus)

		sim.battle = target
		sim.resolveBattle(at: target, won: true, by: .fin)

		let finAfter = sim.buildingsTotal(.army, of: .fin)
		let rusAfter = sim.buildingsTotal(.army, of: .rus)
		#expect(finAfter >= finBefore + 2, "annexed factories did not transfer")
		#expect(rusAfter <= rusBefore - 2, "loser kept the annexed factories")
	}

	@Test func armyMovesThroughOwnLandWithinRange() {
		var sim = StrategicSim.europe(country: .fin)
		let start = sim.armies[Int(Country.fin.rawValue)][0].position
		let range = sim.reachable(by: 0)

		var reachCount = 0
		for xy in sim.owner.indices where range[xy] {
			reachCount += 1
			let own = sim.owner[xy] == .fin
			#expect(own, "move range leaves own territory")
		}
		#expect(reachCount > 0, "main army has nowhere to go")
		#expect(!range[start], "standing still is not a move")

		var oneStep: XY?
		let n4 = start.n4
		for i in 0 ..< n4.count where range[n4[i]] {
			oneStep = n4[i]
			break
		}
		guard let oneStep else {
			Issue.record("no adjacent own tile to step onto")
			return
		}
		let events = sim.reduce(.move(0, oneStep))
		let position = sim.armies[Int(Country.fin.rawValue)][0].position
		let mp = sim.armies[Int(Country.fin.rawValue)][0].mp
		#expect(events.count == 1)
		#expect(position == oneStep)
		#expect(mp == Army.moveSpeed - 1, "one step should cost one mp")

		var farAway: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .fin {
			if xy.stepDistance(to: position) > Int(Army.moveSpeed) { farAway = xy; break }
		}
		if let farAway {
			let denied = sim.reduce(.move(0, farAway))
			let held = sim.armies[Int(Country.fin.rawValue)][0].position
			#expect(denied.isEmpty, "out-of-range move emitted an event")
			#expect(held == oneStep, "out-of-range move happened")
		}
	}

	@Test func foundingArmiesRespectsSlotsAndTiles() {
		var sim = StrategicSim.europe(country: .fin)
		var tiles: [XY] = []
		for xy in sim.owner.indices where sim.owner[xy] == .fin
			&& sim.armyIndex(at: xy) == nil
		{
			tiles.append(xy)
		}
		guard tiles.count >= 4 else {
			Issue.record("Finland too small for the test")
			return
		}

		let occupied = sim.canFound(at: sim.armies[Int(Country.fin.rawValue)][0].position)
		#expect(!occupied, "founding on top of an army allowed")

		for i in 0 ..< 3 {
			let events = sim.reduce(.found(tiles[i]))
			#expect(events.count == 1, "founding army \(i + 2) failed")
		}
		let fifth = sim.reduce(.found(tiles[3]))
		let canFifth = sim.canFound(at: tiles[3])
		#expect(fifth.isEmpty, "a fifth army was founded")
		#expect(!canFifth)

		let mustered = sim.armyIndex(at: tiles[0])
		#expect(mustered == 1, "new army not on its muster tile")
	}

	@Test func endTurnChargesUpkeepAndDisbandsEmptyArmies() {
		var sim = StrategicSim.europe(country: .fin)
		var quiet = sim.reduce(.endTurn)
		#expect(quiet.count == 1, "end turn should always emit its persistence event")

		var tile: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .fin && sim.armyIndex(at: xy) == nil {
			tile = xy
			break
		}
		guard let tile else { return }
		_ = sim.reduce(.found(tile))
		// An empty roster disbands at end of turn before charging upkeep.
		quiet = sim.reduce(.endTurn)
		let disbanded = !sim.armies[Int(Country.fin.rawValue)][1].active
		#expect(quiet.count == 1)
		#expect(disbanded, "an empty army survived the turn")

		_ = sim.reduce(.found(tile))
		sim.armies[Int(Country.fin.rawValue)][1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		let prestige = sim.player.prestige
		let events = sim.reduce(.endTurn)
		let mp = sim.armies[Int(Country.fin.rawValue)][1].mp
		let remaining = sim.player.prestige
		#expect(mp == Army.moveSpeed, "endTurn should restore movement")
		#expect(remaining == prestige - Army.upkeep(slot: 1), "the reducer did not charge upkeep")
		if case .endTurn = events.first {
		} else {
			Issue.record("expected an .endTurn event")
		}
	}

	@Test func armiesAreStoredByCountryRawValue() {
		let sim = StrategicSim.europe(country: .fin)
		let fin = Int(Country.fin.rawValue)
		let rus = Int(Country.rus.rawValue)
		let countryBuckets = sim.armies.count
		let slots = sim.armies[rus].count
		let humanMain = sim.armies[fin][0]
		let russianMain = sim.armies[rus][0]

		#expect(countryBuckets == 64)
		#expect(slots == 4)
		#expect(humanMain.active && sim.owner[humanMain.position] == .fin)
		#expect(russianMain.active && sim.owner[russianMain.position] == .rus)
		#expect(russianMain.strength > 0, "AI main army did not receive a roster")
	}

	@Test func strategicAIRequiresThreeToOneLocalAdvantage() {
		var twoToOne = Self.borderSim(russianUnits: 2)
		twoToOne.runStrategicAI()
		let held = twoToOne.owner[XY(1, 1)]
		#expect(held == .fin, "AI attacked below the required 3:1 advantage")

		var threeToOne = Self.borderSim(russianUnits: 3)
		threeToOne.runStrategicAI()
		let captured = threeToOne.owner[XY(1, 1)]
		let attacker = threeToOne.armies[Int(Country.rus.rawValue)][0]
		#expect(captured == .rus, "AI did not take a battle at exactly 3:1")
		#expect(attacker.position == XY(1, 1))
	}

	@Test func strategicAIMustersAndMovesArmies() {
		var owner = Map<32, Country>(size: 32, zero: .none)
		owner[XY(1, 1)] = .rus
		owner[XY(2, 1)] = .rus
		owner[XY(3, 1)] = .rus
		owner[XY(4, 1)] = .fin
		var sim = StrategicSim(
			owner: owner,
			player: Player(country: .fin, type: .human)
		)
		let rus = Int(Country.rus.rawValue)
		sim.armies[rus][0].active = true
		sim.armies[rus][0].position = XY(1, 1)
		sim.armies[rus][0].mp = Army.moveSpeed
		sim.armies[rus][0].units[0] = Self.infantry(.rus)

		sim.runStrategicAI()

		let main = sim.armies[rus][0]
		let second = sim.armies[rus][1]
		#expect(second.active && second.strength > 0, "AI did not muster a free army slot")
		#expect(main.position != XY(1, 1), "AI main army did not advance toward enemy land")
	}

	@Test func campaignBattleCanAutoresolveWithoutTacticalState() {
		var sim = Self.borderSim(russianUnits: 1)
		let fin = Int(Country.fin.rawValue)
		sim.armies[fin][0].units[1] = Self.infantry(.fin)
		let result = sim.autoResolveAttack(
			at: XY(2, 1),
			by: ArmyID(country: .fin, slot: 0)
		)
		let owner = sim.owner[XY(2, 1)]
		let mp = sim.armies[fin][0].mp
		#expect(result == true)
		#expect(owner == .fin)
		#expect(mp == 0)
		#expect(sim.battle == nil)
	}

	@Test func startCampaignMakesStrategicMainRosterAuthoritative() {
		let unit = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		let hq = HQSim(
			player: Player(country: .fin, type: .human, prestige: 1234, tier: 2),
			units: [16 of COR.Unit](head: [unit], tail: .empty)
		)
		let strategic = StrategicSim.europe(country: .fin)
		var core = Core.new(country: .ger)

		core.startCampaign(hq, strategic)

		let campaign = clone(core.strategic!)
		let country = campaign.player.country
		let prestige = campaign.player.prestige
		let model = campaign.roster(0)[0].model
		#expect(core.location == .strategic)
		#expect(country == .fin)
		#expect(prestige == 1234)
		#expect(model == .regular, "the standalone HQ roster was not assigned to army 0")
	}

	@Test func campaignHQEditsAnyArmyIncludingSlotZero() {
		var strategic = StrategicSim.europe(country: .fin)
		strategic.player.prestige = 900
		strategic.armies[Int(Country.fin.rawValue)][0].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		var core = Core.new(country: .ger)
		core.store(strategic)

		core.openArmy(0)
		var editor = clone(core.hq)
		let openedCountry = editor.player.country
		let openedModel = editor.units[0].model
		#expect(core.location == .hq)
		#expect(editor.army == 0)
		#expect(openedCountry == .fin, "campaign player did not populate the HQ editor")
		#expect(openedModel == .regular)

		editor.player.prestige = 700
		editor.units[0] = modifying(Unit(model: .truck, country: .fin)) { u in u.reset() }
		core.store(editor)
		core.closeArmy()

		let campaign = clone(core.strategic!)
		let storedPrestige = campaign.player.prestige
		let storedModel = campaign.roster(0)[0].model
		#expect(core.location == .strategic)
		#expect(storedPrestige == 700)
		#expect(storedModel == .truck, "army 0 was not synchronized from the HQ editor")
	}

	@Test func winningBattleAdvancesTheArmy() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		sim.battle = target
		sim.battleArmy = 0
		sim.resolveBattle(at: target, won: true, by: .fin)
		let position = sim.armies[Int(Country.fin.rawValue)][0].position
		let cleared = sim.battleArmy == 0
		#expect(position == target, "winning army did not advance")
		#expect(cleared)
	}

	@Test func nearbyArmyProvidesTheDefendingCoreForce() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		// A manned second army right next to the contested tile.
		sim.armies[Int(Country.fin.rawValue)][1].active = true
		sim.armies[Int(Country.fin.rawValue)][1].position = sim.armies[Int(Country.fin.rawValue)][0].position
		sim.armies[Int(Country.fin.rawValue)][1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		sim.armies[Int(Country.fin.rawValue)][1].units[1] = modifying(Unit(model: .truck, country: .fin)) { u in u.reset() }

		let defendingArmy = sim.defendingArmy(for: .fin, near: target)
		let joined = sim.defendingCore(for: .fin, near: target)
		#expect(defendingArmy?.index == 1)
		#expect(joined.count == 2, "nearby army did not provide the core force")
		#expect(joined.allSatisfy { !$0[.aux] }, "defending army was incorrectly marked auxiliary")

		let foreign = sim.defendingCore(for: .rus, near: target)
		#expect(foreign.isEmpty, "selected an army outside defence range")

		sim.armies[Int(Country.fin.rawValue)][1].position = XY(0, 0)
		let tooFar = sim.defendingCore(for: .fin, near: target)
		#expect(tooFar.isEmpty, "army beyond defence range joined")
	}

	@Test func defendingCoreSurvivorsReturnToTheirArmy() {
		let target = XY(2, 1)
		var core = Core.new(country: .ger)
		core.store(Self.borderSim(russianUnits: 2))
		core.startCampaignBattle(at: target)
		var battle = clone(core.tactical!)
		let russianCore = battle.units.reduceAlive(into: [] as [Int]) { result, index, unit in
			if unit.country == .rus, !unit[.aux] { result.append(index) }
		}
		#expect(russianCore.count == 2, "defending army was not fielded as the core force")
		guard let casualty = russianCore.first else { return }
		battle.units[casualty].hp = 0

		core.complete(battle)

		let campaign = clone(core.strategic!)
		let survivors = campaign.roster(0, for: .rus).reduce(into: 0) { count, unit in
			count += unit.alive ? 1 : 0
		}
		#expect(survivors == 1, "defending core casualties were not written back")
	}

	@Test func campaignBattleFieldsTheAttackingArmyRoster() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		// Park a manned second army next to the target and exhaust the main
		// army so slot 1 is the attacker.
		sim.armies[Int(Country.fin.rawValue)][0].mp = 0
		sim.armies[Int(Country.fin.rawValue)][1].active = true
		sim.armies[Int(Country.fin.rawValue)][1].mp = Army.moveSpeed
		sim.armies[Int(Country.fin.rawValue)][1].position = sim.armies[Int(Country.fin.rawValue)][0].position
		sim.armies[Int(Country.fin.rawValue)][0].position = XY(0, 0)
		sim.armies[Int(Country.fin.rawValue)][1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		sim.player.tier = 2

		// Deliberately give Core.hq a different country: once a campaign is
		// active, StrategicSim is the source of truth.
		var core = Core.new(country: .ger)
		core.store(sim)
		core.startCampaignBattle(at: target)

		let tactical = clone(core.tactical!)
		let slot = core.strategic?.battleArmy
		let fielded = tactical.units.reduceAlive(into: 0) { n, _, u in
			n += u.country == .fin && !u[.aux] ? 1 : 0
		}
		#expect(slot == 1, "second army was not picked as the attacker")
		#expect(fielded == 1, "battle did not field the army's own roster")
		#expect(tactical.players[0].country == .fin, "battle used the stale standalone HQ player")
		#expect(tactical.players[0].tier == 2, "battle discarded the campaign player's progression")
	}

	@Test func campaignBattleCompletesIntoStrategicRatherThanStaleHQ() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		sim.armies[Int(Country.fin.rawValue)][0].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }

		var core = Core.new(country: .ger)
		core.store(sim)
		core.startCampaignBattle(at: target)
		var battle = clone(core.tactical!)
		battle[.fin].prestige = 777

		core.complete(battle)

		let campaign = clone(core.strategic!)
		let prestige = campaign.player.prestige
		let survivor = campaign.roster(0)[0]
		let staleCountry = core.hq.player.country
		#expect(core.location == .strategic)
		#expect(prestige == 777, "remaining battle prestige did not return to the campaign")
		#expect(survivor.alive && survivor.country == .fin)
		#expect(staleCountry == .ger, "campaign completion incorrectly treated Core.hq as authoritative")
	}

	@Test func serializationRoundTrip() {
		let original = StrategicSim.europe(country: .fin)
		let data = encode(original)
		guard let restored: StrategicSim = decode(data) else {
			Issue.record("decode failed")
			return
		}
		let human = restored.player.country
		let turn = restored.turn
		let originalTurn = original.turn
		let bytes = encode(restored)
		#expect(human == .fin)
		#expect(turn == originalTurn)
		#expect(bytes == data, "round-trip is not byte-identical")
	}
}

extension StrategicSim {

	static func europe(country: Country) -> Self {
		StrategicSim.europe(player: Player(country: country, type: .human, prestige: .poor, baseLevel: 0, tier: 0, alive: true))
	}
}
