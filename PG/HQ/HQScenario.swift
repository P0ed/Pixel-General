import SpriteKit
import COR

extension HQNodes {

	func scenarioMenu(_ menu: MenuState<HQAction>, _ state: borrowing HQState) -> MenuState<HQAction> {
		var players: [4 of Player] = [
			state.sim.player,
			Player(country: .isr, type: .ai, prestige: .rich, tier: 3),
			Player(country: .usa, type: .ai, prestige: .rich, tier: 3),
			Player(country: .irn, type: .ai, prestige: .rich, tier: 3)
		]
		var countriesLeft: [Country] {
			Country.playable.filter { c in
				!players.contains { $0.alive && $0.country == c }
			}
		}
		var size = 0
		var forts: UInt8 = 0
		var sea: UInt8 = 0
		let sizes: [UIImage] = [.sizeM, .sizeL]

		let countries = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: players[idx].country.flag,
				status: .init(text: "Player \(idx)"),
				update: { menu in
					idx == 0 ? menu : MenuState<HQAction>(
						items: countriesLeft.map { c in
							MenuItem<HQAction>(
								icon: c.flag,
								status: .init(text: "\(c)"),
								update: { _ in
									modifying(menu) { menu in
										players[idx].alive = true
										players[idx].country = c
										menu.items[idx].icon = c.flag
										menu.cursor = idx
									}
								}
							)
						} + [
							.init(icon: .neutral, status: .init(text: "Open"), update: { _ in
								modifying(menu) { menu in
									players[idx].alive = false
									menu.items[idx].icon = .neutral
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
				icon: players[idx].prestige < .rich ? .prestige1 : .prestige2,
				status: .init(text: "Prestige"),
				update: { menu in
					modifying(menu) { menu in
						players[idx].prestige = players[idx].prestige < .rich ? .rich : .poor
						menu.items[8 + idx].icon = players[idx].prestige < .rich ? .prestige1 : .prestige2
						menu.cursor = 8 + idx
					}
				}
			)
		}
		let exp = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: .toggle4(players[idx].baseLevel),
				status: .init(text: "Experience"),
				update: { menu in
					idx == 0 ? menu : modifying(menu) { menu in
						players[idx].baseLevel.toggle4()
						menu.items[12 + idx].icon = .toggle4(players[idx].baseLevel)
						menu.cursor = 12 + idx
					}
				}
			)
		}
		let tier = (0..<4).map { idx in
			MenuItem<HQAction>(
				icon: .toggle4(players[idx].tier),
				status: .init(text: "Tier"),
				update: { menu in
					idx == 0 ? menu : modifying(menu) { menu in
						players[idx].tier.toggle4()
						menu.items[16 + idx].icon = .toggle4(players[idx].tier)
						menu.cursor = 16 + idx
					}
				}
			)
		}
		let start: [MenuItem<HQAction>] = [
			.space, .space,.space, .space,
			.space, .space,.space, .space,

			.init(icon: sizes[size], status: .init(text: "Size: \(24 + size * 8)"), update: { m in
				modifying(m) { m in
					size = (size + 1) % 2
					m.items[28].icon = sizes[size]
					m.items[28].status.text = "Size: \(24 + size * 8)"
				}
			}),
			.init(icon: .toggle4(forts), status: .init(text: "Forts: \(forts)"), update: { m in
				modifying(m) { m in
					forts.toggle4()
					m.items[29].icon = .toggle4(forts)
					m.items[29].status.text = "Forts: \(forts)"
				}
			}),
			.init(icon: .toggle4(sea), status: .init(text: "Sea: \(sea)"), update: { m in
				modifying(m) { m in
					sea.toggle4()
					m.items[30].icon = .toggle4(sea)
					m.items[30].status.text = "Sea: \(sea)"
				}
			}),
			.close(icon: .start, status: "Start", update: { _ in
				guard let scene else { return }

				let units: [Unit] = scene.state.sim.units.compactMap { u in u.alive ? u : nil }
				+ (players[1].alive ? .base(players[1].country, lvl: players[1].baseLevel) : [])
				+ (players[2].alive ? .base(players[2].country, lvl: players[2].baseLevel) : [])
				+ (players[3].alive ? .base(players[3].country, lvl: players[3].baseLevel) : [])
				+ players.flatMap { p in p.alive ? [Unit].aux(p.country, lvl: p.baseLevel) : [] }
				let seed = Int.random(in: 0 ..< 128)

				core.startScenario(Scenario(
					players: players.compactMap { $0.alive ? $0 : nil },
					units: units,
					terrain: Scenario.cornerTerrain(seaLevel: sea, seed: seed),
					fortLevel: Int(forts),
					size: 24 + size * 8,
					seed: seed
				).makeSim())
				core.save()
				view.present(.auto)
			})
		]

		return MenuState(
			items: countries + types + prestige + exp + tier + start,
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

	var icon: UIImage {
		switch self {
		case .human: .human
		case .ai: .AI
		case .remote: .remote
		}
	}
}
