import SpriteKit

extension HQNodes {

	func processScenario(_ state: borrowing HQState) {
		var players: [4 of Player] = [
			state.player,
			Player(country: .isr, type: .ai, prestige: 0x1400),
			Player(country: .usa, type: .ai, prestige: 0x1400),
			Player(country: .irn, type: .ai, prestige: 0x1400)
		]
		var countriesLeft: [Country] {
			Country.allCases.filter { c in
				players.firstMap { $0.country == c ? $0.country : nil } == nil
			}
		}

		let countries = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: "\(players[idx].country)",
				status: .init(text: "Player \(idx)"),
				update: { menu in
					MenuState<HQAction>(
						items: countriesLeft.map { c in
							MenuItem<HQAction>(
								icon: "\(c)",
								status: .init(text: "\(c)"),
								update: { _ in
									players[idx].country = c
									//if idx == 0 {
									//	scene.state.player.country = c
									//	scene.state.units.modifyEach { $1.country = c }
									//	core.store(scene.state)
									//}
									return modifying(menu) { menu in
										menu.items[idx].icon = "\(c)"
										menu.cursor = idx
									}
								}
							)
						},
						close: { _ in
							modifying(menu) { $0.cursor = idx }
						}
					)
				}
			)
		}
		let types = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: players[idx].type.icon,
				status: .init(text: "Player \(idx)"),
				update: { menu in
					modifying(menu) { menu in
						players[idx].type.toggle()
						menu.items[4 + idx].icon = players[idx].type.icon
						menu.cursor = 4 + idx
					}
				}
			)
		}
		let prestige = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: "\(players[idx].prestige < 0x1400 ? "S" : "SS")",
				status: .init(text: "Player \(idx)"),
				update: { menu in
					modifying(menu) { menu in
						players[idx].prestige = players[idx].prestige < 0x1400 ? 0x1400 : 0x0B00
						menu.items[8 + idx].icon = players[idx].prestige < 0x1400 ? "S" : "SS"
						menu.cursor = 8 + idx
					}
				}
			)
		}
		let start = [MenuItem<HQAction>.close(icon: "Start", status: "Start", update: { _ in
			guard let scene else { return }
			core.store(TacticalState.make(
				players: players,
				units: scene.state.units.map { $1 }
			))
			scene.view?.present(core.state)
		})]

		scene?.show(MenuState(
			items: countries + types + prestige + start
		))
	}
}

private extension PlayerType {

	mutating func toggle() {
		self = switch self {
		case .human: .ai
		case .ai: .remote
		case .remote: .human
		}
	}

	var icon: String {
		switch self {
		case .human: "Human"
		case .ai: "AI"
		case .remote: "Remote"
		}
	}
}
