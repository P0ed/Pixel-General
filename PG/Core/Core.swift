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

	func load() {
		if let data = UserDefaults.standard.data(forKey: "state") {
			let decoded: State? = decode(data)
			if decoded != nil { state = decoded! }
		} else {
			new()
		}
	}

	func save() {
		UserDefaults.standard.set(encode(state), forKey: "state")
	}

	func store(hq: borrowing HQState) {
		state.hq = clone(hq)
		save()
	}

	func store(tactical: borrowing TacticalState) {
		guard state.hq != nil else { return }
		state.tactical = clone(tactical)
		save()
	}

	func complete(tactical: borrowing TacticalState) {
		guard let c = state.hq?.player.country else { return }

		let units = tactical.units
		.compactMap { _, u in u.country == c ? u : nil }
		.enumerated().map { i, u in
			modifying(u, { u in
				u.position = XY(i % 4, i / 4)
				u.stats.hp = 0xF
				u.stats.ammo = u.stats[.supply] ? 0 : 0x7
				u.stats.ap = 1
				u.stats.mp = 1
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

extension [Unit] {

	static func template(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: .zero, stats: .base >< .truck),
			Unit(country: country, position: .zero, stats: .base >< .inf),
			Unit(country: country, position: .zero, stats: .base >< .ifv(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank2(country)),
			Unit(country: country, position: .zero, stats: .base >< .art(country)),
			Unit(country: country, position: .zero, stats: .base >< .aa(country)),
			Unit(country: country, position: .zero, stats: .base >< .heli(country)),
		]
	}

	static func base(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: XY(0, 0), stats: .base >< .truck),
			Unit(country: country, position: XY(0, 1), stats: .base >< .inf >< .veteran),
			Unit(country: country, position: XY(3, 0), stats: .base >< .inf >< .veteran),
			Unit(country: country, position: XY(2, 1), stats: .base >< .inf >< .veteran),
			Unit(country: country, position: XY(0, 2), stats: .base >< .tank(country) >< .elite),
			Unit(country: country, position: XY(0, 3), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(1, 0), stats: .base >< .ifv(country) >< .veteran),
			Unit(country: country, position: XY(2, 0), stats: .base >< .ifv(country) >< .elite),
			Unit(country: country, position: XY(1, 1), stats: .base >< .art(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .art(country) >< .veteran),
		]
	}
}
