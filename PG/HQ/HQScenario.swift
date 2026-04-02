import SpriteKit

extension HQScene {

	func processScenario() {
		var players: [4 of Player] = [
			state.player,
			Player(country: .isr, ai: true, prestige: 0xF00),
			Player(country: .usa, ai: true, prestige: 0xF00),
			Player(country: .irn, ai: true, prestige: 0xF00)
		]
		var countriesLeft: [Country] {
			Country.allCases.filter { c in
				players.firstMap { $0.country == c ? $0.country : nil } == nil
			}
		}
		var menu: MenuState<State>? = .none

		menu = MenuState<State>(
			items: (0..<4).map { idx in
				MenuItem(icon: "\(players[idx].country)", status: "Player \(idx)", update: { _ in
					MenuState(
						items: countriesLeft.map { c in
							MenuItem(icon: "\(c)", status: "\(c)", update: { state in
								players[idx].country = c
								if idx == 0 {
									state.player.country = c
									state.units.modifyEach { $1.country = c }
									core.store(hq: state)
								}
								menu?.items[idx].icon = "\(c)"
								menu?.cursor = idx
								return menu
							})
						},
						close: { _ in
							menu?.cursor = idx
							return menu
						}
					)
				})
			}
			+ (0..<4).map { idx in
				MenuItem(icon: "\(players[idx].ai ? "AI" : "Human")", status: "Player \(idx)", update: { state in
					players[idx].ai.toggle()
					menu?.items[4 + idx].icon = players[idx].ai ? "AI" : "Human"
					menu?.cursor = 4 + idx
					return menu
				})
			}
			+ (0..<4).map { idx in
				MenuItem(icon: "\(players[idx].prestige <= 0xA00 ? "s" : "ss")", status: "Player \(idx)", update: { state in
					players[idx].prestige = players[idx].prestige <= 0xA00 ? 0xF00 : 0xA00
					menu?.items[8 + idx].icon = players[idx].prestige <= 0xA00 ? "s" : "ss"
					menu?.cursor = 8 + idx
					return menu
				})
			}
			+ [MenuItem.close(icon: "Start", status: "Start", update: { [weak self] state in
				menu = nil
				core.store(tactical: .make(
					players: players,
					units: state.units.map { $1 }
				))
				self?.view?.present(core.state)
			})],
			close: { _ in
				menu = nil
				return nil
			}
		)
		show(menu)
	}
}
