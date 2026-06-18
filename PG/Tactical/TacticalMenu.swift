import SpriteKit
import AVFoundation
import COR

extension TacticalNodes {

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.show(.none)
		}

		var vol: Int {
			let v = scene.audioEngine.mainMixerNode.outputVolume
			return v < 0.1 ? 0 : v < 0.5 ? 1 : 2
		}
		let toggleVol = { [audioEngine = scene.audioEngine] in
			settings.toggleSound()
			audioEngine.mainMixerNode.outputVolume = settings.outputVolume
		}

		scene.show(MenuState(
			items: [
				.close(icon: .start, status: "End turn", action: .end),
				.space,
				.load { [weak scene] in scene?.saveState() },
				(
					state.sim.canRetreat
					? .close(icon: .HQ, status: "Retreat") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
					: .close(icon: .HQ, status: "Abandon") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
				),

				MenuItem(
					icon: .prestige1,
					status: .init(text: "Prestige: \(state.sim.player.prestige)"),
					update: id
				),
				.space,
				.space,
				(
					state.sim.canDraw
					? .close(icon: .HQ, status: "Draw") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
					: .space
				),

				MenuItem(icon: UIImage(named: "Sound\(vol)") ?? .clear, status: .init(text: "Volume"), update: { menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[8].icon = UIImage(named: "Sound\(vol)") ?? .clear
					}
				}),
				.space,
				.space,
				.space,
			]
		))
	}

}
