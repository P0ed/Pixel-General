import UIKit
import COR

extension MenuItem {

	static var prefs: MenuItem {
		.push(icon: .settings, status: "Settings", menu: {
			MenuState(
				items: [
					.toggle(icon: .sound(settings.soundLevel), status: "Volume") {
						settings.toggleSound()
					},
					.toggle(icon: .toggle4(settings.animationSpeed), status: "Animation speed") {
						settings.toggleAnimation()
					},
					.toggle(icon: .toggle(settings.ai), status: "Neural opponent") {
						settings.ai.toggle()
					},
					.toggle(icon: .toggle(settings.campaignAutoresolve), status: "Battle autoresolve") {
						settings.campaignAutoresolve.toggle()
					},
				],
				leftButtons: [.back, .space, .space, .space]
			)
		})
	}
}

extension UIImage {

	static func sound(_ level: UInt8) -> UIImage {
		UIImage(named: "Sound\(level)") ?? .clear
	}
}
