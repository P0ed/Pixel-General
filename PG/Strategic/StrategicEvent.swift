import SpriteKit
import COR

extension StrategicNodes {

	func process(_ event: StrategicEvent, _ state: borrowing StrategicState) async {
		switch event {
		case .attack(let xy): processAttack(xy)
		case .menu: processMenu(state)
		}
	}

	private func processAttack(_ xy: XY) {
		guard let scene else { return }
		core.store(scene.state.sim) // persist the strategic map before the battle
		core.startCampaignBattle(at: xy)
		core.save()
		view.present(.auto)
	}

	private func processMenu(_ state: borrowing StrategicState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.showMenu(.none)
		}

		scene.showMenu(MenuState(
			items: [
				.space,
				.space,
				.load { [weak scene] in scene?.saveState() },
				.close(icon: .HQ, status: "HQ") { _ in
					core.goHQ()
					core.save()
					view.present(.auto)
				},
			]
		))
	}
}
