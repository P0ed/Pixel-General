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

	func process(_ events: [HQEvent], _ state: borrowing HQState) async {
		for event in events { await process(event, state) }
	}

	private func process(_ event: HQEvent, _ state: borrowing HQState) async {
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
			items: [Unit].shop(country: state.country).map { [xy = state.cursor] u in
				.close(
					icon: u.imageName,
					status: u.status,
					action: "\(u.cost) / \(state.player.prestige) ><",
					update: { state in state.buy(u, at: xy) }
				)
			}
		))
	}

	private func processMenu() {
		(root as? HQScene)?.show(MenuState(items: [
			.close(icon: "New", status: "New") { [weak root] _ in
				core.new()
				(root as? HQScene)?.view?.present(core.state)
			},
			.close(icon: "Save", status: "Save") { state in
				core.store(state, auto: false)
			},
			.close(icon: "Load", status: "Load") { [weak root] _ in
				core.load(auto: false)
				(root as? HQScene)?.view?.present(core.state)
			},
			.close(icon: "Chess", status: "Chess", update: { [weak root] _ in
				core.store(TacticalState.chess())
				(root as? HQScene)?.view?.present(core.state)
			})
		]))
	}
}
