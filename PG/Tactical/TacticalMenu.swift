import SpriteKit
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.showMenu(.none)
		}

		var vol: Int { Int(settings.soundLevel) }
		let toggleVol = { settings.toggleSound() }

		scene.showMenu(MenuState(
			items: [
				.close(icon: .start, status: "End turn", action: .end),
				.space,
				.load { [weak scene] in scene?.saveState() },
				.close(icon: .HQ, status: "Abandon") { [weak scene] _ in
					if let scene { endGame(scene.state) }
				},

				MenuItem(
					icon: .prestige1,
					status: .init(text: "Prestige: \(state.sim.player.prestige)"),
					update: id
				),
				.space,
				.space,
				.space,

				MenuItem(icon: UIImage(named: "Sound\(vol)") ?? .clear, status: .init(text: "Volume"), update: { menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[8].icon = UIImage(named: "Sound\(vol)") ?? .clear
					}
				}),
				MenuItem(icon: .toggle4(settings.animationSpeed), status: .init(text: "Animation speed"), update: { menu in
					modifying(menu) { menu in
						settings.toggleAnimation()
						menu.items[9].icon = .toggle4(settings.animationSpeed)
					}
				}),
				MenuItem(icon: .toggle4(settings.aiKind == 0 ? 0 : 3), status: .init(text: "Neural opponent"), update: { menu in
					modifying(menu) { menu in
						settings.toggleAI()
						menu.items[10].icon = .toggle4(settings.aiKind == 0 ? 0 : 3)
					}
				}),
				.space,
			]
		))
	}

}
