import Testing
import Foundation
@testable import COR

/// Phase-1 campaign layer: the European map factory, province adjacency/attack
/// rules, the annex-on-win flip, and serialization of the strategic state.
///
/// `StrategicState` is noncopyable, so every value read by `#expect` is hoisted
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

	@Test func europeFactoryParsesMap() {
		let sim = StrategicSim.europe(human: .fin)
		let size = sim.owner.size
		let human = sim.human
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
		let sim = StrategicSim.europe(human: .fin)
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

	@Test func canAttackEnemyBorderTile() {
		let sim = StrategicSim.europe(human: .fin)
		let target = Self.borderTile(sim, human: .fin, target: .rus)
		#expect(target != nil, "no Finland/Russia border on the europe map")
		if let target {
			let attackable = sim.canAttack(target)
			#expect(attackable)
		}
	}

	@Test func cannotAttackOwnOrSea() {
		let sim = StrategicSim.europe(human: .fin)
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
		var sim = StrategicSim.europe(human: .fin)
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
		var sim = StrategicSim.europe(human: .fin)
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
		var sim = StrategicSim.europe(human: .fin)
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
		var sim = StrategicSim.europe(human: .fin)
		let day = sim.turn
		let events = sim.reduce(.endTurn)
		let turn = sim.turn
		#expect(turn == day + 1)
		#expect(events.isEmpty)
	}

	@Test func reduceAttackEmitsEvent() {
		var sim = StrategicSim.europe(human: .fin)
		let events = sim.reduce(.attack(XY(0, 0)))
		#expect(events.count == 1)
		if case .attack = events.first {} else {
			Issue.record("expected an .attack event")
		}
	}

	@Test func serializationRoundTrip() {
		let original = StrategicSim.europe(human: .fin)
		let data = encode(original)
		guard let restored: StrategicSim = decode(data) else {
			Issue.record("decode failed")
			return
		}
		let human = restored.human
		let turn = restored.turn
		let originalTurn = original.turn
		let bytes = encode(restored)
		#expect(human == .fin)
		#expect(turn == originalTurn)
		#expect(bytes == data, "round-trip is not byte-identical")
	}
}
