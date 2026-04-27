import SpriteKit

extension HQNodes {

	func campaignMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState(items: [
			.close(icon: "Start", status: "Start") { m in
				core.startCampaign(StrategicState())
				present(.make(core.state))
			}
		])
	}
}
