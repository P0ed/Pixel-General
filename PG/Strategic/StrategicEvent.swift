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
		core.store(scene.state) // persist the strategic map before the battle
		core.startCampaignBattle(at: xy)
		core.save(auto: true)
		present(.auto)
	}

	private func processMenu(_ state: borrowing StrategicState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.show(.none)
		}

		scene.show(MenuState(
			items: [
				.close(icon: "HQ", status: "HQ") { /*[weak scene]*/ _ in
					core.goHQ()
					core.save(auto: true)
					present(.auto)
				},
				.close(icon: "Save", status: "Save") { [weak scene] _ in
					if let scene {
						core.store(scene.state)
						core.save(auto: false)
					}
				},
				.close(icon: "Load", status: "Load") { _ in
					core = .load(auto: false)
					present(.auto)
				},
			]
		))
	}
}
