import SpriteKit
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene else { return }
		if state.sim.isFinished {
			scene.showMenu(HQMenu().menu())
			return
		}

		scene.showMenu(MenuState(
			items: [
				.close(icon: .arrowRight, status: "End turn", action: .end),
				.apply(icon: .prestige1, status: "Prestige: \(state.sim.player.prestige)"),
			],
			leftButtons: [
				.back,
				.space,
				.space,
				.prefs,
			],
			rightButtons: [
				.load { [weak scene] in scene?.saveState() },
				.space,
				.space,
				.init(icon: .HQ, status: Status(text: "Abandon scenario")) { [weak scene] stack, _ in
					guard let scene else { return }
					scene.state.abandon()
					stack = [HQMenu().menu()]
				}
			]
		))
	}
}
