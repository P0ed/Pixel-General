import SpriteKit
import COR

extension HQNodes {

	func process(_ event: HQEvent, _ state: borrowing HQState) async {
		switch event {
		case .move(let uid, let xy): processMove(uid, xy)
		case .spawn(let uid): processSpawn(uid, state)
		case .remove(let uid): removeUnit(uid)
		}
	}

	func present(_ intent: HQPresentationIntent, _ state: borrowing HQState) async {
		switch intent {
		case .shop: processShop(state)
		case .upgrade(let uid): processUpgrade(uid, state)
		case .menu: processMenu()
		}
	}

	private func processMove(_ uid: UID, _ xy: XY) {
		units[uid.index]?.position = xy.point
		units[uid.index]?.zPosition = map.zPosition(at: xy)
	}

	private func processSpawn(_ uid: UID, _ state: borrowing HQState) {
		let sprite = state.sim.units[uid.index].hqSprite
		let xy = XY(uid.index % 4, uid.index / 4)
		sprite.position = xy.point
		sprite.zPosition = map.zPosition(at: xy)
		addUnit(uid, node: sprite)
	}

	private func processShop(_ state: borrowing HQState) {
		scene?.showMenu(.init(
			items: Shop(country: state.sim.country, tier: state.sim.player.tier).units.enumerated().map { i, u in
				.close(
					icon: u.image,
					status: .init(text: u.status(), action: .init("\(u.cost) / \(state.sim.player.prestige)")),
					action: .purchase(i, state.ui.cursor.x + state.ui.cursor.y * 4)
				)
			},
			leftButtons: [.back, .space, .space, .space]
		))
	}

	private func processUpgrade(_ uid: UID, _ state: borrowing HQState) {
		let unit = state.sim.units[uid.index]
		let prestige = state.sim.player.prestige
		let options = Shop(country: state.sim.country, tier: state.sim.player.tier).upgrades(for: unit)

		scene?.showMenu(.init(
			items: options.map { option in
				let result = unit.upgraded(to: option.model)
				return .close(
					icon: result.image,
					status: .init(text: result.status(), action: .init("\(unit.upgradeCost(to: option.model)) / \(prestige)")),
					action: .upgrade(uid.index, option.model)
				)
			},
			leftButtons: [.back, .space, .space, .space]
		))
	}

	private func processMenu() {
		guard core.strategic == nil else {
			return _ = scene?.showMenu(MenuState(
				items: [
					.close(icon: .HQ, status: "Back") {
						guard let scene else { return }
						core.store(scene.state.sim)
						core.closeArmy()
						core.save()
						view.present(.auto)
					},
				],
				leftButtons: [.back, .space, .space, .space]
			))
		}

		scene?.showMenu(MenuState(
			items: [
				.push(icon: .start, status: "Scenario", menu: {
					guard let scene else { return nil }
					return scenarioMenu(scene.state)
				}),
				.push(icon: .remote, status: "Host LAN", menu: {
					guard let scene else { return nil }
					return hostMenu(scene.state)
				}),
				.push(icon: .remote, status: "Join LAN", menu: {
					joinMenu()
				}),
				.push(icon: .start, status: "Campaign", menu: {
					guard let scene else { return nil }
					return campaignMenu(scene.state)
				}),
			],
			leftButtons: [.back, .space, .space, .space],
			rightButtons: [
				.push(icon: .plus, status: "New", menu: {
					guard let scene else { return nil }
					return newGameMenu(scene.state)
				}),
				.load { scene?.saveState() },
				.prefs,
				.close(icon: .chess, status: "Editor") {
					guard let scene else { return }
					core.store(scene.state.sim)
					view.present(.editor)
				},
			]
		))
	}
}
