import Testing
import Foundation
@testable import COR

/// Phase-1 campaign layer: the European map factory, province adjacency/attack
/// rules, the annex-on-win flip, and serialization of the strategic state.
///
/// `StrategicSim` is noncopyable, so every value read by `#expect` is hoisted
/// into a local first — the macro captures its expression and would otherwise
/// require `Copyable`.
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
					sim.armies[0].position = n
					sim.armies[0].mp = Army.moveSpeed
					return xy
				}
			}
		}
		return nil
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
		#expect(events.isEmpty)
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
		let start = sim.armies[0].position
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
		let position = sim.armies[0].position
		let mp = sim.armies[0].mp
		#expect(events.count == 1)
		#expect(position == oneStep)
		#expect(mp == Army.moveSpeed - 1, "one step should cost one mp")

		var farAway: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .fin {
			if xy.stepDistance(to: position) > Int(Army.moveSpeed) { farAway = xy; break }
		}
		if let farAway {
			let denied = sim.reduce(.move(0, farAway))
			let held = sim.armies[0].position
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

		let occupied = sim.canFound(at: sim.armies[0].position)
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
		#expect(quiet.isEmpty, "the free main army charged upkeep")

		var tile: XY?
		for xy in sim.owner.indices where sim.owner[xy] == .fin && sim.armyIndex(at: xy) == nil {
			tile = xy
			break
		}
		guard let tile else { return }
		_ = sim.reduce(.found(tile))
		// An empty roster disbands at end of turn before charging upkeep.
		quiet = sim.reduce(.endTurn)
		let disbanded = !sim.armies[1].active
		#expect(quiet.isEmpty, "an empty army charged upkeep")
		#expect(disbanded, "an empty army survived the turn")

		_ = sim.reduce(.found(tile))
		sim.armies[1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		let events = sim.reduce(.endTurn)
		let mp = sim.armies[1].mp
		#expect(mp == Army.moveSpeed, "endTurn should restore movement")
		if case .upkeep(let cost) = events.first {
			#expect(cost == Army.upkeep(slot: 1))
		} else {
			Issue.record("expected an .upkeep event for the second army")
		}
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
		let position = sim.armies[0].position
		let cleared = sim.battleArmy == 0
		#expect(position == target, "winning army did not advance")
		#expect(cleared)
	}

	@Test func auxReinforcementJoinsFromNearbyArmy() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		// A manned second army right next to the contested tile.
		sim.armies[1].active = true
		sim.armies[1].position = sim.armies[0].position
		sim.armies[1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }
		sim.armies[1].units[1] = modifying(Unit(model: .truck, country: .fin)) { u in u.reset() }

		let joined = sim.reinforcement(for: .fin, near: target)
		#expect(joined.count == 2, "nearby army did not reinforce")
		#expect(joined.allSatisfy { $0[.aux] }, "reinforcements not marked aux")

		let foreign = sim.reinforcement(for: .rus, near: target)
		#expect(foreign.isEmpty, "reinforced a country without armies")

		sim.armies[1].position = XY(0, 0)
		let tooFar = sim.reinforcement(for: .fin, near: target)
		#expect(tooFar.isEmpty, "army beyond auxJoinRange reinforced")
	}

	@Test func campaignBattleFieldsTheAttackingArmyRoster() {
		var sim = StrategicSim.europe(country: .fin)
		guard let target = Self.stageAttack(&sim) else {
			Issue.record("no border tile to contest")
			return
		}
		// Park a manned second army next to the target and exhaust the main
		// army so slot 1 is the attacker.
		sim.armies[0].mp = 0
		sim.armies[1].active = true
		sim.armies[1].mp = Army.moveSpeed
		sim.armies[1].position = sim.armies[0].position
		sim.armies[0].position = XY(0, 0)
		sim.armies[1].units[0] = modifying(Unit(model: .regular, country: .fin)) { u in u.reset() }

		var core = Core.new(country: .fin)
		core.store(sim)
		core.startCampaignBattle(at: target)

		let tactical = clone(core.tactical!)
		let slot = core.strategic?.battleArmy
		let fielded = tactical.units.reduceAlive(into: 0) { n, _, u in
			n += u.country == .fin && !u[.aux] ? 1 : 0
		}
		#expect(slot == 1, "second army was not picked as the attacker")
		#expect(fielded == 1, "battle did not field the army's own roster")
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
