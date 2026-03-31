import SpriteKit

enum HQEvent {
	case move(UID, XY)
	case spawn(UID)
	case remove(UID)
	case shop
	case scenario
	case menu
	case none
}

extension HQScene {

	func process(events: [Event]) async {
		for event in events { await process(event) }
	}

	func respawn() {
		state.units.forEach { i, u in processSpawn(uid: i) }		
	}

	private func process(_ event: Event) async {
		switch event {
		case .move(let uid, let xy): processMove(uid: uid, xy: xy)
		case .spawn(let uid): processSpawn(uid: uid)
		case .remove(let uid): removeUnit(uid)
		case .shop: processShop()
		case .scenario: processScenario()
		case .menu: processMenu()
		case .none: break
		}
	}

	private func processMove(uid: UID, xy: XY) {
		nodes?.units[uid]?.position = xy.point
		nodes?.units[uid]?.zPosition = nodes?.map.zPosition(at: xy) ?? 0.0
	}

	private func processSpawn(uid: UID) {
		guard let nodes else { return }

		let sprite = state.units[uid].hqSprite
		let xy = state.units[uid].position
		sprite.position = HQNodes.map.point(at: xy)
		sprite.zPosition = nodes.map.zPosition(at: xy)
		addUnit(uid, node: sprite)
	}

	private func processShop() {
		show(.init(
			items: [Unit].shop(country: state.country).map { [xy = state.cursor] u in
				.init(
					icon: u.imageName,
					status: u.status,
					action: "\(u.cost) / \(state.player.prestige) ><",
					update: { state in state.buy(u, at: xy) }
				)
			}
		))
	}

	private func processScenario() {
		var players: [4 of Player] = [
			state.player,
			Player(country: .isr, ai: true, prestige: 0xF00),
			Player(country: .usa, ai: true, prestige: 0xF00),
			Player(country: .irn, ai: true, prestige: 0xF00)
		]
		let showMenu = { [weak self] items in
			_ = Task { self?.show(MenuState(items: items)) }
		}
		var upd = {}
		let selectCountry: (Int) -> Void = { idx in
			showMenu(Country.allCases.map { c in
				.init(icon: "\(c)", status: "\(c)", update: { state in
					players[idx].country = c
					Task { upd() }
				})
			})
		}
		let update = { [weak self] in
			showMenu(
				(0..<4).map { idx in
					MenuItem(icon: "\(players[idx].country)", status: "Player \(idx)", update: { state in
						selectCountry(idx)
					})
				}
				+ (0..<4).map { idx in
					MenuItem(icon: "\(players[idx].ai ? "AI" : "Human")", status: "Player \(idx)", update: { state in
						players[idx].ai.toggle()
						upd()
					})
				}
				+ (0..<4).map { idx in
					MenuItem(icon: "\(players[idx].prestige == 0xF00 ? "$$" : "$")", status: "Player \(idx)", update: { state in
						players[idx].prestige = players[idx].prestige == 0xF00 ? 0xA00 : 0xF00
						upd()
					})
				}
				+ [
					MenuItem(icon: "Start", status: "Start", update: { state in
						core.store(tactical: .make(
							players: players,
							units: state.units.map { $1 }
						))
						self?.view?.present(core.state)
					}),
				]
			)
		}
		upd = update
		update()
	}

	private func processMenu() {
		show(MenuState(items: [
			.init(icon: "New", status: "New") { [weak self] _ in
				core.new()
				self?.view?.present(core.state)
			},
			.init(icon: "Save", status: "Save") { state in
				core.store(hq: state, auto: false)
			},
			.init(icon: "Load", status: "Load") { [weak self] _ in
				core.load(auto: false)
				self?.view?.present(core.state)
			},
		]))
	}
}
