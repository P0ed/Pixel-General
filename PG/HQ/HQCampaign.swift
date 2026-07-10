import SpriteKit
import COR

extension HQNodes {

	func campaignMenu(_ menu: MenuState<HQAction>, _ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState(
			items: [
				core.strategic != nil
				? .close(icon: .start, status: .init(text: "Continue")) { m in
					guard let scene else { return }
					core.continueCampaign(scene.state.sim)
					core.save()
					view.present(.auto)
				}
				: .close(icon: .start, status: .init(text: "Start")) { m in
					guard let scene else { return }
					core.startCampaign(scene.state.sim, .europe(player: scene.state.sim.player))
					core.save()
					view.present(.auto)
				}
			],
			close: { _ in menu }
		)
	}
}
