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
		let slot = state.ui.cursor.x + state.ui.cursor.y * 4
		scene?.showMenu(.shop(
			units: Shop(country: state.sim.country, tier: state.sim.player.tier).units,
			prestige: state.sim.player.prestige,
			purchase: { index, _ in .purchase(index, slot) }
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
					status: .init(text: "\(unit.upgradeCost(to: option.model)) / \(prestige)\n" + result.status()),
					action: .upgrade(uid.index, option.model)
				)
			},
			leftButtons: [.back, .space, .space, .space]
		))
	}
}
