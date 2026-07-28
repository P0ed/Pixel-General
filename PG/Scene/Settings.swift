import Foundation
import COR

struct Settings {
	var soundLevel: UInt8 = 1
	var animationSpeed: UInt8 = 1
	var ai: Bool = false
	var campaignAutoresolve: Bool = false
}

extension Settings {

	mutating func toggleSound() {
		soundLevel = (soundLevel + 1) % 3
	}

	var outputVolume: Float {
		switch soundLevel {
		case 0: 0.0
		case 1: 0.3
		default: 1.0
		}
	}

	mutating func toggleAnimation() {
		animationSpeed.toggle4()
	}

	mutating func toggleCampaignAutoresolve() {
		campaignAutoresolve.toggle()
	}

	var animationScale: Double {
		Double(animationSpeed + 1) / Double(animationSpeed * 2 + 1)
	}
}
