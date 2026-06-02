import SpriteKit
import COR

extension HQNodes {

	func campaignMenu(_ menu: MenuState<HQAction>, _ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState(
			items: [
				.close(icon: "Start", status: .init(text: "Start")) { m in
					guard let scene else { return }
					core.startCampaign(scene.state, StrategicState())
					core.save(auto: true)
					present(.auto)
				}
			],
			close: { _ in menu }
		)
	}
}
