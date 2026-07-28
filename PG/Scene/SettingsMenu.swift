import UIKit
import COR

extension MenuItem {

	static var prefs: MenuItem {
		.push(icon: .settings, status: "Settings", menu: {
			MenuState(
				items: [
					.update(
						icon: .sound(settings.soundLevel),
						status: "Volume",
						menu: { menu in
							settings.toggleSound()
							menu.items[0].icon = .sound(settings.soundLevel)
						}
					),
					.update(
						icon: .toggle4(settings.animationSpeed),
						status: "Animation speed",
						menu: { menu in
							settings.toggleAnimation()
							menu.items[1].icon = .toggle4(settings.animationSpeed)
						}
					),
					.update(
						icon: .toggle(settings.ai),
						status: "Neural opponent",
						menu: { menu in
							settings.ai.toggle()
							menu.items[2].icon = .toggle(settings.ai)
						}
					),
					.update(
						icon: .toggle(settings.campaignAutoresolve),
						status: "Battle autoresolve",
						menu: { menu in
							settings.toggleCampaignAutoresolve()
							menu.items[3].icon = .toggle(settings.campaignAutoresolve)
						}
					),
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
