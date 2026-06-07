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
		_ state: borrowing StrategicState,
		human: Country,
		target: Country
	) -> XY? {
		for xy in state.owner.indices where state.owner[xy] == target {
			let n8 = xy.n8
			for i in 0 ..< n8.count {
				let n = n8[i]
				if state.owner.contains(n), state.owner[n] == human {
					return xy
				}
			}
		}
		return nil
	}

	@Test func europeFactoryParsesMap() {
		let state = StrategicState.europe(human: .fin)
		let size = state.owner.size
		let human = state.human
		let inBattle = state.battle != nil
		#expect(size == 32)
		#expect(human == .fin)
		#expect(!inBattle)

		var fin = 0, rus = 0, sea = 0
		for xy in state.owner.indices {
			switch state.owner[xy] {
			case .fin: fin += 1
			case .rus: rus += 1
			case .sea: sea += 1
			default: break
			}
		}
		#expect(fin > 0, "Finland missing from the map")
		#expect(rus > 0, "Russia missing from the map")
		#expect(sea > 0, "water tiles missing from the map")
	}

	@Test func canAttackEnemyBorderTile() {
		let state = StrategicState.europe(human: .fin)
		let target = Self.borderTile(state, human: .fin, target: .rus)
		#expect(target != nil, "no Finland/Russia border on the europe map")
		if let target {
			let attackable = state.canAttack(target)
			#expect(attackable)
		}
	}

	@Test func cannotAttackOwnOrSea() {
		let state = StrategicState.europe(human: .fin)
		var ownTile: XY?
		var seaTile: XY?
		for xy in state.owner.indices {
			if state.owner[xy] == .fin, ownTile == nil { ownTile = xy }
			if state.owner[xy] == .sea, seaTile == nil { seaTile = xy }
		}
		if let ownTile {
			let attackable = state.canAttack(ownTile)
			#expect(!attackable, "own tile is attackable")
		}
		if let seaTile {
			let attackable = state.canAttack(seaTile)
			#expect(!attackable, "sea tile is attackable")
		}
	}

	@Test func resolveBattleAnnexesOnWin() {
		var state = StrategicState.europe(human: .fin)
		guard let target = Self.borderTile(state, human: .fin, target: .rus) else {
			Issue.record("no border tile to contest")
			return
		}
		state.battle = target
		state.resolveBattle(at: target, won: true, by: .fin)
		let owner = state.owner[target]
		let inBattle = state.battle != nil
		#expect(owner == .fin, "won battle did not annex the tile")
		#expect(!inBattle, "battle context not cleared")
	}

	@Test func resolveBattleKeepsTileOnLoss() {
		var state = StrategicState.europe(human: .fin)
		guard let target = Self.borderTile(state, human: .fin, target: .rus) else {
			Issue.record("no border tile to contest")
			return
		}
		state.battle = target
		state.resolveBattle(at: target, won: false, by: .fin)
		let owner = state.owner[target]
		let inBattle = state.battle != nil
		#expect(owner == .rus, "repulse should not flip the tile")
		#expect(!inBattle, "battle context not cleared")
	}

	@Test func resolveBattleDoesNotFloodSea() {
		var state = StrategicState.europe(human: .fin)
		// Pick a sea tile so the capture radius certainly overlaps water.
		var seaTile: XY?
		for xy in state.owner.indices where state.owner[xy] == .sea {
			seaTile = xy
			break
		}
		guard let seaTile else { return }
		state.resolveBattle(at: seaTile, won: true, by: .fin)
		let owner = state.owner[seaTile]
		#expect(owner == .sea, "sea was converted to land")
	}

	@Test func reduceEndTurnAdvancesDay() {
		var state = StrategicState.europe(human: .fin)
		let day = state.turn
		let events = state.reduce(.endTurn)
		let turn = state.turn
		#expect(turn == day + 1)
		#expect(events.isEmpty)
	}

	@Test func reduceAttackEmitsEvent() {
		var state = StrategicState.europe(human: .fin)
		let events = state.reduce(.attack(XY(0, 0)))
		#expect(events.count == 1)
		if case .attack = events.first {} else {
			Issue.record("expected an .attack event")
		}
	}

	@Test func serializationRoundTrip() {
		let original = StrategicState.europe(human: .fin)
		let data = encode(original)
		guard let restored: StrategicState = decode(data) else {
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
