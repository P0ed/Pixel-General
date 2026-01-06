import Foundation

struct State: ~Copyable {
	var hq: HQState?
	var strategic: StrategicState?
	var tactical: TacticalState?
}

final class Core {
	private(set) var state = State()

	func new(country: Country = .ukr) {
		let units: [Unit] = .base(country)
		state = State(
			hq: HQState(
				player: Player(country: country),
				units: .init(head: units, tail: .dead)
			)
		)
		save()
	}

	func load(auto: Bool = true) {
		if let data = UserDefaults.standard.data(forKey: auto ? "auto" : "main") {
			let decoded: State? = decode(data)
			if decoded != nil { state = decoded! }
		} else {
			new()
		}
	}

	func save(auto: Bool = true) {
		UserDefaults.standard.set(encode(state), forKey: auto ? "auto" : "main")
	}

	func store(hq: borrowing HQState, auto: Bool = true) {
		state.hq = clone(hq)
		save(auto: auto)
	}

	func store(tactical: borrowing TacticalState, auto: Bool = true) {
		guard state.hq != nil else { return }
		state.tactical = clone(tactical)
		save(auto: auto)
	}

	func complete(tactical: borrowing TacticalState) {
		guard let c = state.hq?.player.country else { return }

		let units = tactical.units
		.compactMap { _, u in u.country == c ? u : nil }
		.enumerated().map { i, u in
			modifying(u, { u in
				u.position = XY(i % 4, i / 4)
				u.stats.hp = 0xF
				u.stats.mp = 1
				u.stats.ap = 1
				u.stats.ammo = 0x7
				u.stats.ent = 0
			})
		}
		state.hq?.units = .init(head: units, tail: .dead)
		state.hq?.cursor = .zero
		state.hq?.player.prestige = tactical.players.firstMap {
			$1.country == c ? $1.prestige : nil
		} ?? 0

		state.tactical = nil
		save()
	}
}
