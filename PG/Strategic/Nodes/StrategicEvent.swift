import SpriteKit

enum StrategicEvent {
	case menu
}

extension StrategicNodes {

	func process(_ event: StrategicEvent, _ state: borrowing StrategicState) async {
		switch event {
		case .menu: processMenu(state)
		}
	}

	private func processMenu(_ state: borrowing StrategicState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.show(.none)
		}

		scene.show(MenuState(
			items: [
				.close(icon: "HQ", status: "HQ") { /*[weak scene]*/ _ in
//					if let scene {
//						core.complete(state)
//						present(.make(core.state))
//					}
				},
				.close(icon: "Save", status: "Save") { [weak scene] _ in
					if let scene {
						core.store(scene.state, auto: false)
					}
				},
				.close(icon: "Load", status: "Load") { _ in
					core.load(auto: false)
					present(.make(core.state))
				},
			]
		))
	}
}
