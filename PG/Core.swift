import Foundation

final class Core {
	private(set) var state = State()

	var settings: Settings {
		get {
			UserDefaults.standard.data(forKey: "settings").flatMap(decode) ?? Settings()
		}
		set {
			UserDefaults.standard.set(encode(newValue), forKey: "settings")
		}
	}

	func new(country: Country = .default) {
		state = State(
			hq: HQState(
				player: Player(country: country),
				units: .init(
					head: .base(country).mapInPlace { u in u.hp = u.maxHP },
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

	func store(_ hq: borrowing HQState, auto: Bool = true) {
		state.hq = clone(hq)
		save(auto: auto)
	}

	func store(_ tactical: borrowing TacticalState, auto: Bool = true) {
		guard state.hq != nil else { return }
		state.tactical = clone(tactical)
		save(auto: auto)
	}

	func store(_ strategic: borrowing StrategicState, auto: Bool = true) {
		guard state.hq != nil else { return }
		state.strategic = clone(strategic)
		save(auto: auto)
	}

	func startScenario(_ tactical: borrowing TacticalState) {
		state.tactical = clone(tactical)
		state.location = .tactical
		save()
	}

	func startCampaign(_ strategic: borrowing StrategicState) {
		state.strategic = clone(strategic)
		state.location = .strategic
		save()
	}

	func complete(_ tactical: borrowing TacticalState) {
		guard let c = state.hq?.player.country, tactical.map.size == 32 else {
			state.tactical = nil
			save()
			return
		}

		let units: [Unit] = tactical.units
			.compactMap { i, u in
				u.country != c || u[.aux] ? nil : modifying(u) { u in
					u.hp = u.maxHP
					u.ap = u.maxAP
					u.mp = u.maxMP
					u.ammo = u.maxAmmo
					u.ent = 0
				}
			}
		state.hq?.units = .init(head: Array(units.prefix(16)), tail: .empty)
		state.hq?.cursor = .zero
		state.hq?.player.prestige = tactical.players.firstMap {
			$1.country == c ? $1.prestige : nil
		} ?? 0

		state.tactical = nil
		state.location = .hq
		save()
	}

	func goHQ() {
		guard state.location == .strategic else { return }
		state.location = .hq
		save()
	}

	func connect(to host: String = "locaclhost") {
		let client = Client<Message>(handleMessage: ø)
		client.connect(host: host, port: 9899)
	}
}

import SpriteKit

extension SKScene {

	static func make(_ state: borrowing State) -> SKScene {
		switch state.location {
		case .hq: Scene(mode: .hq, state: clone(state.hq!))
		case .strategic: Scene(mode: .strategic, state: clone(state.strategic!))
		case .tactical: Scene(mode: .tactical, state: clone(state.tactical!))
		}
	}
}
