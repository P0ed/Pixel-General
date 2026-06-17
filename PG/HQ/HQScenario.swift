import SpriteKit
import COR

extension HQNodes {

	func scenarioMenu(_ menu: MenuState<HQAction>, _ state: borrowing HQState) -> MenuState<HQAction> {
		var players: [4 of Player] = [
			state.player,
			Player(country: .isr, type: .ai, prestige: .rich),
			Player(country: .usa, type: .ai, prestige: .rich),
			Player(country: .irn, type: .ai, prestige: .rich)
		]
		var countriesLeft: [Country] {
			Country.playable.filter { c in
				players.firstMap { $0.alive && $0.country == c ? $0.country : nil } == nil
			}
		}
		var size = 0
		let sizes = ["SizeS", "SizeM", "SizeL"]

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
									modifying(menu) { menu in
										players[idx].alive = true
										players[idx].country = c
										menu.items[idx].icon = "\(c)"
										menu.cursor = idx
									}
								}
							)
						} + [
							.init(icon: "neutral", status: .init(text: "Open"), update: { _ in
								modifying(menu) { menu in
									players[idx].alive = false
									menu.items[idx].icon = "neutral"
									menu.cursor = idx
								}
							})
						],
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
				icon: "\(players[idx].prestige < .rich ? "Prestige1" : "Prestige2")",
				status: .init(text: "Player \(idx)"),
				update: { menu in
					modifying(menu) { menu in
						players[idx].prestige = players[idx].prestige < .rich ? .rich : .poor
						menu.items[8 + idx].icon = players[idx].prestige < .rich ? "Prestige1" : "Prestige2"
						menu.cursor = 8 + idx
					}
				}
			)
		}
		let start: [MenuItem<HQAction>] = [
			.space, .space,
			.init(icon: sizes[size], status: .init(text: "Size: \(16 + size * 8)"), update: { m in
				modifying(m) { m in
					size = (size + 1) % 3
					m.items[14].icon = sizes[size]
					m.items[14].status.text = "Size: \(16 + size * 8)"
				}
			}),
			.close(icon: "Start", status: "Start", update: { _ in
				guard let scene else { return }
				core.startScenario(TacticalState.make(
					players: players.compactMap { $0.alive ? $0 : nil },
					units: scene.state.units.compactMap { u in u.alive ? u : nil },
					size: 16 + size * 8,
					seed: .random(in: 0..<128)
				))
				core.save()
				present(.auto)
			})
		]

		return MenuState(
			items: countries + types + prestige + start,
			close: { _ in menu }
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
