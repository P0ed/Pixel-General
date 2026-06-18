import SpriteKit
import COR

extension HQNodes {

	func process(_ event: HQEvent, _ state: borrowing HQState) async {
		switch event {
		case .move(let uid, let xy): processMove(uid, xy)
		case .spawn(let uid): processSpawn(uid, state)
		case .remove(let uid): removeUnit(uid)
		case .shop: processShop(state)
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
		scene?.show(.init(
			items: Shop(country: state.sim.country).units.enumerated().map { i, u in
				.close(
					icon: u.image,
					status: .init(text: u.status(), action: .init("\(u.cost) / \(state.sim.player.prestige)")),
					action: .purchase(i, state.ui.cursor.x + state.ui.cursor.y * 4)
				)
			}
		))
	}

	private func processMenu() {
		scene?.show(MenuState(items: [
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
				core.startScenario(TacticalState.chess())
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
				core.store(scene.state)
				view.present(.editor)
			},
		]))
	}
}
