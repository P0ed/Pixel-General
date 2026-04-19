import SpriteKit

enum HQEvent {
	case move(UID, XY)
	case spawn(UID)
	case remove(UID)
	case shop
	case scenario
	case menu
}

extension HQNodes {

	func process(_ event: HQEvent, _ state: borrowing HQState) async {
		switch event {
		case .move(let uid, let xy): processMove(uid, xy)
		case .spawn(let uid): processSpawn(uid, state)
		case .remove(let uid): removeUnit(uid)
		case .shop: processShop(state)
		case .scenario: processScenario(state)
		case .menu: processMenu()
		}
	}

	private func processMove(_ uid: UID, _ xy: XY) {
		units[uid.index]?.position = xy.point
		units[uid.index]?.zPosition = map.zPosition(at: xy)
	}

	private func processSpawn(_ uid: UID, _ state: borrowing HQState) {
		let sprite = state.units[uid.index].hqSprite
		let xy = XY(uid.index % 4, uid.index / 4)
		sprite.position = HQNodes.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		addUnit(uid, node: sprite)
	}

	private func processShop(_ state: borrowing HQState) {
		(root as? HQScene)?.show(.init(
			items: [Unit].shop(country: state.country).enumerated().map { i, u in
				.close(
					icon: u.imageName,
					status: .init(text: u.status, action: .init("\(u.cost) / \(state.player.prestige) ><")),
					action: .purchase(i, state.cursor.x + state.cursor.y * 4)
				)
			}
		))
	}

	private func processMenu() {
		scene?.show(MenuState(items: [
			.close(icon: "New", status: .init(text: "New")) { [weak root] _ in
				core.new()
				(root as? HQScene)?.view?.present(core.state)
			},
			.close(icon: "Save", status: .init(text: "Save")) { _ in
				if let scene {
					core.store(scene.state, auto: false)
				}
			},
			.close(icon: "Load", status: .init(text: "Load")) { _ in
				core.load(auto: false)
				scene?.view?.present(core.state)
			},
			.close(icon: "Chess", status: .init(text: "Chess"), update: { _ in
				core.store(TacticalState.chess())
				scene?.view?.present(core.state)
			})
		]))
	}
}
