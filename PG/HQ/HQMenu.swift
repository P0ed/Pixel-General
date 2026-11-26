import SpriteKit
import COR

extension HQNodes {

	func processMenu() {
		scene?.showMenu(MenuState(
			items: [.space],
			leftButtons: [
				.back,
				.push(icon: .plus, status: "New", menu: {
					guard let scene else { return nil }
					return newGameMenu(scene.state)
				}),
				.load { scene?.saveState() },
				.prefs
			],
			rightButtons: [
				.push(icon: .arrowRight, status: "Scenario", menu: {
					guard let scene else { return nil }
					return scenarioMenu(scene.state)
				}),
				.space,
				.space,
				.space,
			]
		))
	}

	private func newGameMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState<HQAction>(
			items: Country.playable.map { c in
				.close(
					icon: c.flag,
					status: "\(c)",
					update: {
						core = .new(country: c)
						core.save()
						view.present(.auto)
					}
				)
			},
			leftButtons: [.back, .space, .space, .space]
		)
	}
}
