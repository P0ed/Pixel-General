import SpriteKit
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.showMenu(.none)
		}

		scene.showMenu(MenuState(
			items: [
				.close(icon: .arrowRight, status: "End turn", action: .end),
				.apply(icon: .prestige1, status: "Prestige: \(state.sim.player.prestige)"),
			],
			leftButtons: [.back, .space, .space, .space],
			rightButtons: [
				.space,
				.load { [weak scene] in scene?.saveState() },
				.prefs,
				.close(icon: .HQ, status: "Abandon") { [weak scene] in
					if let scene { endGame(scene.state) }
				}
			]
		))
	}
}
