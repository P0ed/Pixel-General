import SpriteKit
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TACSceneState) {
		guard let scene else { return }
		if state.tac.isFinished {
			scene.showMenu(HQMenu().menu())
			return
		}

		scene.showMenu(Menu(
			leftButtons: [
				.back,
				.space,
				.space,
				.prefs,
			],
			rightButtons: [
				.close(icon: .arrowRight, status: "End turn", action: .end),
				.apply(icon: .prestige1, status: "Prestige: \(state.tac.player.prestige)"),
				.load { [weak scene] in scene?.saveState() },
				.init(icon: .HQ, status: Status(text: "Abandon scenario"), action: .abandon) { stack, _ in
					stack = [HQMenu().menu()]
				}
			]
		))
	}
}
