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
				.close(icon: "Start", status: "End turn", action: .end),
				.close(icon: "Save", status: "Save") { [weak scene] _ in
					if let scene {
						core.store(scene.state)
						core.save(auto: false)
					}
				},
				.close(icon: "Load", status: "Load") { _ in
					core = .load(auto: false)
					present(.auto)
				},
				(
					state.canRetreat
					? .close(icon: "HQ", status: "Retreat") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
					: .close(icon: "HQ", status: "Abandon") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
				),

				MenuItem(
					icon: "Prestige1",
					status: .init(text: "Prestige: \(state.player.prestige)"),
					update: id
				),
				.space,
				.space,
				(
					state.canDraw
					? .close(icon: "HQ", status: "Draw") { [weak scene] _ in
						if let scene { endGame(scene.state) }
					}
					: .space
				),

				MenuItem(icon: "Sound\(vol)", status: .init(text: "Volume"), update: { menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[8].icon = "Sound\(vol)"
					}
				}),
				.space,
				.space,
				.space,
			]
		))
	}

}
