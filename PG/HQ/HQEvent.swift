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
			}
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
			}
		))
	}

	private func processMenu() {
		// Editing an army roster from the campaign: no scenario/LAN items,
		// just the way back to the strategic map.
		guard core.army == 0 else {
			scene?.showMenu(MenuState(items: [
				.close(icon: .HQ, status: "Back") { _ in
					guard let scene else { return }
					core.store(scene.state.sim)
					core.closeArmy()
					core.save()
					view.present(.auto)
				},
			]))
			return
		}
		scene?.showMenu(MenuState(items: [
			.init(icon: .start, status: .init(text: "Scenario"), update: { m in
				guard let scene else { return nil }
				return scenarioMenu(m, scene.state)
			}),
			.init(icon: .remote, status: .init(text: "Host LAN"), update: { m in
				guard let scene else { return nil }
				return hostMenu(m, scene.state)
			}),
			.init(icon: .remote, status: .init(text: "Join LAN"), update: { m in
				joinMenu(m)
			}),
			.space,

			.init(icon: .start, status: .init(text: "Campaign"), update: { m in
				guard let scene else { return nil }
				return campaignMenu(m, scene.state)
			}),
			.space, .space, .space,

			.close(icon: .chess, status: .init(text: "Chess"), update: { _ in
				core.startScenario(.chess())
				view.present(.auto)
			}),
			.space, .space, .space,

			.init(icon: .new, status: .init(text: "New")) { _ in
				guard let scene else { return nil }
				return newGameMenu(scene.state)
			},
			.load { scene?.saveState() },
			.space,
			.close(icon: .chess, status: .init(text: "Editor")) { _ in
				guard let scene else { return }
				core.store(scene.state.sim)
				view.present(.editor)
			},
		]))
	}
}
