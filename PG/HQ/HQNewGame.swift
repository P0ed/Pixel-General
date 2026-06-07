import SpriteKit
import COR

extension HQNodes {

	func newGameMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState<HQAction>(
			items: Country.playable.map { c in
				.close(
					icon: "\(c)",
					status: "\(c)",
					update: { _ in
						core = .new(country: c)
						core.save(auto: true)
						present(.auto)
					}
				)
			}
		)
	}
}
