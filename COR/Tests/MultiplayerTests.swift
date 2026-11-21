import Testing
import Foundation
@testable import COR

/// Guards the invariants the multiplayer action relay rests on: `reduce` is a
/// pure deterministic function of `(state, action)`, and states/actions
/// survive the `encode`/`decode` wire round-trip.
struct MultiplayerTests {

	private static func players() -> [Player] {
		let countries: [4 of Country] = [.swe, .usa, .rus, .pak]
		return (0 ..< 4).map { i in
			Player(country: countries[i], type: .ai, prestige: 0xF00)
		}
	}

	private static func make(seed: Int = 7) -> TacticalSim {
		TacticalSim(
			players: players(),
			units: .small(.swe) + .small(.usa) + .small(.rus) + .small(.pak),
			seed: seed
		)
	}

	/// Everything `reduce` reads or writes except the peer-relative
	/// `PlayerType` and the never-reduced UI fields (cursor, selection,
	/// camera), which are allowed to diverge between peers.
	private func gameStateEqual(_ a: borrowing TacticalSim, _ b: borrowing TacticalSim) -> Bool {
		guard a.turn == b.turn, a.d20 == b.d20,
			  a.objective == b.objective, a.settlements == b.settlements
		else { return false }
		for i in 0 ..< 4 {
			guard a.players[i].country == b.players[i].country,
				  a.players[i].prestige == b.players[i].prestige,
				  a.players[i].alive == b.players[i].alive,
				  a.vision[i] == b.vision[i]
			else { return false }
		}
		for i in 0 ..< 128 {
			guard a.units[i] == b.units[i],
				  a.position[i] == b.position[i],
				  a.cargo[i] == b.cargo[i]
			else { return false }
		}
		for xy in a.map.indices {
			guard a.map[xy] == b.map[xy],
				  a.control[xy] == b.control[xy],
				  a.unitsMap[xy] == b.unitsMap[xy]
			else { return false }
		}
		return true
	}

	@Test func identicalActionStreamKeepsPeersIdentical() {
		var a = Self.make()
		var b = Self.make()
		var ai = AI.Plan()

		let identicalAtStart = gameStateEqual(a, b)
		#expect(identicalAtStart, "Same-seed states must start identical")

		var diverged = false
		var steps = 0
		while steps < 256 {
			let action = a.run(ai: &ai)
			_ = a.reduce(action)
			_ = b.reduce(action)
			steps += 1
			if !gameStateEqual(a, b) {
				diverged = true
				break
			}
			if action == .end, a.turn > 8 { break }
		}

		#expect(!diverged, "States diverged after \(steps) identical actions")
		#expect(a.turn > 0, "The action stream never advanced the turn")
	}

	@Test func takeoverHandsSeatToAI() {
		var a = Self.make()
		_ = a.reduce(.takeover(.usa))
		#expect(a[.usa].type == .ai)
	}

	@Test func actionSerializationRoundTrip() {
		let actions: [TacticalAction] = [
			.move(3.uid, XY(63, 63)),
			.embark(1.uid, 2.uid),
			.disembark(7.uid, XY(0, 63)),
			.attack(12.uid, 100.uid),
			.resupply(127.uid),
			.purchase(5, XY(16, 16)),
			.takeover(.usa),
			.end,
		]
		for action in actions {
			#expect(decode(encode(action)) == action)
		}
		#expect(decode(Data()) as TacticalAction? == nil, "Size mismatch must fail, not crash")
	}

	@Test func stateSerializationRoundTrip() {
		var state = Self.make(seed: 12)
		let corner = XY(63, 63)
		state.map[corner] = .city
		state.control[corner] = .swe
		state.indexSettlements()
		state.place(0.uid, at: corner)
		state.vision[0] = state.vision(for: .swe)
		guard let copy: TacticalSim = decode(encode(state)) else {
			Issue.record("State failed to decode")
			return
		}
		let survived = gameStateEqual(state, copy)
		#expect(survived, "Decoded state differs from the original")
		#expect(copy.settlements[corner])
		#expect(copy.unitsMap[corner] == 0.uid)
		#expect(copy.vision[0][corner])
	}

	@Test func firstEndTurnRecomputesAirfieldControlAfterResume() {
		let home = XY(2, 3)
		let away = XY(12, 12)
		let airfield = XY(3, 3)
		let nearby = XY(4, 3)
		var map = Map<64, Terrain>(zero: .field)
		map[home] = .city
		map[away] = .city
		map[airfield] = .airfield
		var state = TacticalSim(
			map: map,
			players: [Player(country: .swe), Player(country: .rus)],
			cities: [(home, .swe), (away, .rus)],
			units: []
		)
		state.control[airfield] = .rus
		state.control[nearby] = .rus
		state.vision[0] = state.vision(for: .swe)
		state.vision[1] = state.vision(for: .rus)
		let prestige = state[.swe].prestige

		guard var resumed: TacticalSim = decode(encode(state)) else {
			Issue.record("State failed to decode")
			return
		}
		#expect(resumed.control[airfield] == .rus)
		#expect(resumed.vision[1][nearby])
		_ = resumed.reduce(.end)
		#expect(resumed.control[airfield] == .swe)
		#expect(resumed.control[nearby] == .swe)
		#expect(resumed[.swe].prestige == prestige + 24 + 4)
		#expect(resumed.vision[0][nearby])
		#expect(!resumed.vision[1][nearby])
	}
}
