import SpriteKit

extension HQScene {

	func processScenario() {
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

		show(MenuState<State>(
			items: (0..<4).map { idx in
				MenuItem(icon: "\(players[idx].country)", status: "Player \(idx)", update: { _, menu in
					MenuState(
						items: countriesLeft.map { c in
							MenuItem(icon: "\(c)", status: "\(c)", update: { state, _ in
								players[idx].country = c
								if idx == 0 {
									state.player.country = c
									state.units.modifyEach { $1.country = c }
									core.store(hq: state)
								}
								return modifying(menu) { menu in
									menu.items[idx].icon = "\(c)"
									menu.cursor = idx
								}
							})
						},
						close: { _ in
							modifying(menu) { $0.cursor = idx }
						}
					)
				})
			}
			+ (0..<4).map { idx in
				MenuItem(icon: players[idx].type.icon, status: "Player \(idx)", update: { state, menu in
					modifying(menu) { menu in
						players[idx].type.toggle()
						menu.items[4 + idx].icon = players[idx].type.icon
						menu.cursor = 4 + idx
					}
				})
			}
			+ (0..<4).map { idx in
				MenuItem(icon: "\(players[idx].prestige < 0x1400 ? "S" : "SS")", status: "Player \(idx)", update: { state, menu in
					modifying(menu) { menu in
						players[idx].prestige = players[idx].prestige < 0x1400 ? 0x1400 : 0x0B00
						menu.items[8 + idx].icon = players[idx].prestige < 0x1400 ? "S" : "SS"
						menu.cursor = 8 + idx
					}
				})
			}
			+ [MenuItem.close(icon: "Start", status: "Start", update: { [weak self] state in
				core.store(tactical: .make(
					players: players,
					units: state.units.map { $1 }
				))
				self?.view?.present(core.state)
			})]
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
