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

	private static func make(seed: Int = 7) -> TacticalState {
		TacticalState(
			players: players(),
			objective: .ffa,
			units: .small(.swe) + .small(.usa) + .small(.rus) + .small(.pak),
			size: 24,
			seed: seed
		)
	}

	/// Everything `reduce` reads or writes except the peer-relative
	/// `PlayerType` and the never-reduced UI fields (cursor, selection,
	/// camera), which are allowed to diverge between peers.
	private func gameStateEqual(_ a: borrowing TacticalState, _ b: borrowing TacticalState) -> Bool {
		guard a.sim.turn == b.sim.turn, a.sim.d20 == b.sim.d20 else { return false }
		for i in 0 ..< 4 {
			guard a.sim.players[i].country == b.sim.players[i].country,
				  a.sim.players[i].prestige == b.sim.players[i].prestige,
				  a.sim.players[i].alive == b.sim.players[i].alive,
				  a.sim.players[i].visible == b.sim.players[i].visible
			else { return false }
		}
		for i in 0 ..< 128 {
			guard a.sim.units[i] == b.sim.units[i],
				  a.sim.position[i] == b.sim.position[i],
				  a.sim.cargo[i] == b.sim.cargo[i]
			else { return false }
		}
		for xy in a.sim.map.indices {
			guard a.sim.map[xy] == b.sim.map[xy],
				  a.sim.control[xy] == b.sim.control[xy],
				  a.sim.unitsMap[xy] == b.sim.unitsMap[xy]
			else { return false }
		}
		return true
	}

	@Test func identicalActionStreamKeepsPeersIdentical() {
		var a = Self.make()
		var b = Self.make()
		var ai = TacticalSim.AI()

		let identicalAtStart = gameStateEqual(a, b)
		#expect(identicalAtStart, "Same-seed states must start identical")

		var diverged = false
		var steps = 0
		while steps < 512 {
			let action = a.sim.axis(ai: &ai)
			_ = a.reduce(action)
			_ = b.reduce(action)
			steps += 1
			if !gameStateEqual(a, b) {
				diverged = true
				break
			}
			if action == .end, a.sim.turn > 8 { break }
		}

		#expect(!diverged, "States diverged after \(steps) identical actions")
		#expect(a.sim.turn > 0, "The action stream never advanced the turn")
	}

	@Test func takeoverHandsSeatToAI() {
		var a = Self.make()
		_ = a.reduce(.takeover(.usa))
		#expect(a.sim[.usa].type == .ai)
	}

	@Test func actionSerializationRoundTrip() {
		let actions: [TacticalAction] = [
			.move(3.uid, XY(5, 9)),
			.embark(1.uid, 2.uid),
			.disembark(7.uid, XY(0, 31)),
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
		let state = Self.make(seed: 12)
		guard let copy: TacticalState = decode(encode(state)) else {
			Issue.record("State failed to decode")
			return
		}
		let survived = gameStateEqual(state, copy)
		#expect(survived, "Decoded state differs from the original")
	}
}
