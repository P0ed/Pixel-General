import SpriteKit

extension HQNodes {

	func scenarioMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		var players: [4 of Player] = [
			state.player,
			Player(country: .isr, type: .ai, prestige: .rich),
			Player(country: .usa, type: .ai, prestige: .rich),
			Player(country: .irn, type: .ai, prestige: .rich)
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
					idx == 0 ? menu : MenuState<HQAction>(
						items: countriesLeft.map { c in
							MenuItem<HQAction>(
								icon: "\(c)",
								status: .init(text: "\(c)"),
								update: { _ in
									players[idx].country = c
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
					idx == 0 ? menu : modifying(menu) { menu in
						players[idx].type.toggle()
						menu.items[4 + idx].icon = players[idx].type.icon
						menu.cursor = 4 + idx
					}
				}
			)
		}
		let prestige = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: "\(players[idx].prestige < .rich ? "S" : "SS")",
				status: .init(text: "Player \(idx)"),
				update: { menu in
					modifying(menu) { menu in
						players[idx].prestige = players[idx].prestige < .rich ? .rich : .poor
						menu.items[8 + idx].icon = players[idx].prestige < .rich ? "S" : "SS"
						menu.cursor = 8 + idx
					}
				}
			)
		}
		let start: [MenuItem<HQAction>] = [
			.space, .space, .space,
			.close(icon: "Start", status: "Start", update: { _ in
				guard let scene else { return }
				core.startScenario(TacticalState.make(
					players: players,
					units: scene.state.units.compactMap { u in u.alive ? u : nil }
				))
				present(.make(core.state))
			})
		]

		return MenuState(
			items: countries + types + prestige + start
		)
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

private extension UInt16 {

	static var poor: Self { 0x0B00 }
	static var rich: Self { 0x1400 }
}
