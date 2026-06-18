import SpriteKit
import COR

extension HQNodes {

	func newGameMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState<HQAction>(
			items: Country.playable.map { c in
				.close(
					icon: c.flag,
					status: "\(c)",
					update: { _ in
						core = .new(country: c)
						core.save()
						view.present(.auto)
					}
				)
			}
		)
	}
}
