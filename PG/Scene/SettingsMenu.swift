import SpriteKit
import COR

extension MenuItem {

	static func prefs(map: MapNodes) -> MenuItem {
		.push(icon: .settings, status: "Settings", menu: {
			MenuState(
				items: [
					.toggle(icon: .sound(settings.soundLevel), status: "Volume") {
						settings.toggleSound()
					},
					.toggle(icon: .toggle4(settings.animationSpeed), status: "Animation speed") {
						settings.toggleAnimation()
					},
					.toggle(icon: .toggle(settings.gridLines), status: settings.gridLines ? "Grid Lines On" : "Grid Lines Off") {
						settings.gridLines.toggle()
						map.setGridLines(settings.gridLines)
					},
				],
				leftButtons: [.back, .space, .space, .space]
			)
		})
	}
}
