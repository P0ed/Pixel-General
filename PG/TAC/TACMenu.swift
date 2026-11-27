import SpriteKit
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene else { return }
		if state.sim.isFinished {
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
				.apply(icon: .prestige1, status: "Prestige: \(state.sim.player.prestige)"),
				.load { [weak scene] in scene?.saveState() },
				.init(icon: .HQ, status: Status(text: "Abandon scenario")) { [weak scene] stack, _ in
					guard let scene else { return }
					scene.state.abandon()
					stack = [HQMenu().menu()]
				}
			]
		))
	}
}
