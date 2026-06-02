import Foundation
import COR

struct Settings {
	var soundLevel: UInt8 = 1
}

@MainActor
var settings: Settings = UserDefaults.standard.data(forKey: "settings").flatMap(decode) ?? Settings() {
	didSet {
		UserDefaults.standard.set(encode(settings), forKey: "settings")
	}
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
}
