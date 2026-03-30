import Foundation

struct State: ~Copyable {
	var hq: HQState?
	var strategic: StrategicState?
	var tactical: TacticalState?
}

final class Core {
	private(set) var state = State()

	func new(country: Country = .default) {
		let units: [Unit] = [Unit].base(country)
		state = State(
			hq: HQState(
				player: Player(country: country),
				units: .init(head: units, tail: .empty)
			)
		)
		save()
	}

	func load(auto: Bool = true, reset: Bool = false) {
		if reset {
			return new()
		}
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

		let units: [Unit] = \.grid4x4 § tactical.units.compactMap { _, u in
			u.country != c ? nil : modifying(u, { u in
				u.hp = 0xF
				u.ap = 0b11
				u.ammo = u.maxAmmo
				u.ent = 0
			})
		}
		state.hq?.units = .init(head: Array(units.prefix(16)), tail: .empty)
		state.hq?.cursor = .zero
		state.hq?.player.prestige = tactical.players.firstMap {
			$1.country == c ? $1.prestige : nil
		} ?? 0

		state.tactical = nil
		save()
	}
}
