import SpriteKit

extension HQNodes {

	func newGameMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState<HQAction>(
			items: Country.allCases.map { c in
				.close(
					icon: "\(c)",
					status: "\(c)",
					update: { _ in
						core.new(country: c)
						present(.make(core.state))
					}
				)
			}
		)
	}
}
