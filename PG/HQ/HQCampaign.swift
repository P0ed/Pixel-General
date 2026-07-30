import SpriteKit
import COR

extension HQNodes {

	func campaignMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState(
			items: [
				.close(icon: .arrowRight, status: "Start") { [weak scene] in
					guard let scene else { return }
					core.startCampaign(scene.state.sim, .europe(player: scene.state.sim.player))
					core.save()
					view.present(.auto)
				}
			],
			leftButtons: [.back, .space, .space, .space]
		)
	}
}
