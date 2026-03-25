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

extension HQEvent: DeadOrAlive {

	var alive: Bool { if case .none = self { false } else { true } }
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
		core.store(tactical: .make(
			player: state.player,
			units: state.units.map { $1 }
		))
		view?.present(core.state)
	}

	private func processMenu() {
		show(.init(items: [
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
