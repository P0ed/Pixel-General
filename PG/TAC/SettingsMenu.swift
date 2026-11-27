import SpriteKit
import COR

extension MenuItem {

	static var prefs: MenuItem {
		.push(icon: .settings, status: "Settings", menu: {
			Menu(
				items: [
					.toggle(icon: .sound(settings.soundLevel), status: "Volume") {
						settings.toggleSound()
					},
					.toggle(icon: .toggle4(settings.animationSpeed), status: "Animation speed") {
						settings.toggleAnimation()
					},
				],
				leftButtons: [.back, .space, .space, .space]
			)
		})
	}
}
