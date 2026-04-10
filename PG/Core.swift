import Foundation

struct State: ~Copyable {
	var hq: HQState?
	var strategic: StrategicState?
	var tactical: TacticalState?
}

struct Settings {
	var soundLevel: UInt8 = 2
}

final class Core {
	private(set) var state = State()
	var settings = Settings()

	func new(country: Country = .default) {
		state = State(
			hq: HQState(
				player: Player(country: country),
				units: .init(
					head: .base(country).mapInPlace { u in u.hp = 0xF },
					tail: .empty
				)
			)
		)
		save()
	}

	func load(auto: Bool = true) {
		if let data = UserDefaults.standard.data(forKey: auto ? "auto" : "main"),
		   let decoded = decode(data) as State? {
			state = decoded
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
		guard let c = state.hq?.player.country, tactical.map.size == 32 else {
			state.tactical = nil
			save()
			return
		}

		let units: [Unit] = \.grid4x4 § (
			tactical.units.map { $1 } + tactical.cargo.compactMap { $0.alive ? $0 : nil }
		).compactMap { u in
			u.country != c || u[.aux] ? nil : modifying(u, { u in
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

	func connect(to host: String = "locaclhost") {
		let client = Client<Message>(handleMessage: ø)
		client.connect(host: host, port: 9899)
	}
}
