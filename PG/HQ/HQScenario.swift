import SpriteKit
import COR

extension HQNodes {

	func scenarioMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		var players: [4 of Player] = [
			state.sim.player,
			Player(country: .isr, type: .ai, prestige: .rich),
			Player(country: .usa, type: .ai, prestige: .rich),
			Player(country: .irn, type: .ai, prestige: .rich),
		]
		var countriesLeft: [Country] {
			Country.playable.filter { c in
				!players.contains { $0.alive && $0.country == c }
			}
		}
		var forts: UInt8 = 0
		var sea: UInt8 = 0
		var density: UInt8 = 0
		var spawns: [4 of UInt8] = .init(repeating: 5)

		let countries = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: players[idx].country.flag,
				status: .init(text: "Player \(idx)"),
				update: { stk, _ in
					guard idx > 0 else { return }
					stk.append(MenuState<HQAction>(
						items: countriesLeft.map { c in
							.pop(icon: c.flag, status: "\(c)") { menu in
								players[idx].alive = true
								players[idx].country = c
								menu.items[idx].icon = c.flag
								menu.cursor = idx
							}
						} + [
							.pop(icon: .neutral, status: "Open") { menu in
								players[idx].alive = false
								menu.items[idx].icon = .neutral
								menu.cursor = idx
							}
						],
						leftButtons: [.back, .space, .space, .space]
					))
				}
			)
		}
		let types = (0..<4).map { idx in
			MenuItem<HQAction>.toggle(icon: players[idx].type.icon, status: "Player \(idx)") {
				guard idx > 0 else { return }
				players[idx].type.toggle()
			}
		}
		let prestige = (0..<4).map { idx in
			MenuItem<HQAction>.toggle(
				icon: players[idx].prestige < .rich ? .prestige1 : .prestige2,
				status: "Prestige"
			) {
				players[idx].prestige = players[idx].prestige < .rich ? .rich : .poor
			}
		}
		let exp = (0..<4).map { idx in
			MenuItem<HQAction>.toggle(icon: .toggle4(players[idx].baseLevel), status: "Experience") {
				guard idx > 0 else { return }
				players[idx].baseLevel.toggle4()
			}
		}
		let tier = (0..<4).map { idx in
			MenuItem<HQAction>.toggle(icon: .toggle4(players[idx].tier), status: "Tier") {
				guard idx > 0 else { return }
				players[idx].tier.toggle4()
			}
		}
		let spawn = (0..<4).map { idx in
			MenuItem<HQAction>.toggle(icon: .spawn(spawns[idx]), status: "Spawn") {
				spawns[idx].toggle6()
			}
		}

		return MenuState(
			items: countries + types + prestige + exp + tier + spawn,
			leftButtons: [.back, .space, .space, .space],
			rightButtons: [
				.toggle(icon: .toggle4(density), status: "Density: \(density)") { density.toggle4() },
				.toggle(icon: .toggle4(forts), status: "Forts: \(forts)") { forts.toggle4() },
				.toggle(icon: .toggle4(sea), status: "Sea: \(sea)") { sea.toggle4() },
				.close(icon: .arrowRight, status: "Start", update: { [weak scene] in
					guard let scene else { return }

					let units: [Unit] = scene.state.sim.units.compactMap { u in u.alive ? u : nil }
					+ (players[1].alive ? .base(players[1].country, lvl: players[1].baseLevel) : [])
					+ (players[2].alive ? .base(players[2].country, lvl: players[2].baseLevel) : [])
					+ (players[3].alive ? .base(players[3].country, lvl: players[3].baseLevel) : [])
					+ players.flatMap { p in p.alive ? [Unit].aux(p.country, lvl: p.baseLevel) : [] }
					let seed = Int.random(in: 0 ..< 1024)
					let options = XY.one.c5

					core.startScenario(.init(new: Scenario(
						players: players.compactMap { $0.alive ? $0 : nil },
						units: units,
						terrain: Scenario.cornerTerrain(seaLevel: sea, seed: seed),
						spawns: .init { i in spawns[i] < spawns.count ? options[spawns.count - i] : nil },
						cityLevel: Int(density),
						fortLevel: Int(forts),
						seed: seed
					)))
					core.save()
					view.present(.auto)
				})
			]
		)
	}
}

extension PlayerType {

	mutating func toggle() {
		self = switch self {
		case .human: .ai
		case .ai: .human
		case .remote: .remote
		}
	}

	var icon: UIImage {
		switch self {
		case .human: .human
		case .ai: .AI
		case .remote: .remote
		}
	}
}
