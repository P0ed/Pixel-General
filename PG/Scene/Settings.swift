import Foundation
import COR

struct Settings {
	var soundLevel: UInt8 = 1
	var animationSpeed: UInt8 = 1
	/// Tactical AI opponent: 0 = classic heuristic, 1 = neural (LSTM),
	/// falling back to classic when no weights are bundled.
	var aiKind: UInt8 = 0
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

	mutating func toggleAI() {
		aiKind = aiKind == 0 ? 1 : 0
	}

	var animationScale: Double {
		1.5 / Double(animationSpeed + 1)
	}
}
