import Foundation
import COR

private struct LegacySettings {
	var soundLevel: UInt8
	var animationSpeed: UInt8
}

extension UserDefaults {

	var slot: Int {
		get { integer(forKey: "slot") }
		set { set(newValue, forKey: "slot") }
	}

	func load(slot: Int) -> Core {
		self.slot = slot
		return data(
			forKey: "slot-\(slot)"
		).flatMap { data in
			decode(data) as Core?
		} ?? .new(country: .default)
	}

	func save(_ state: borrowing Core) {
		set(
			encode(state),
			forKey: "slot-\(slot)"
		)
	}

	var settings: Settings {
		get {
			guard let data = data(forKey: "settings") else { return Settings() }
			if let stored: Settings = decode(data) { return stored }
			if let legacy: LegacySettings = decode(data) {
				return Settings(soundLevel: legacy.soundLevel, animationSpeed: legacy.animationSpeed)
			}
			return Settings()
		}
		set { set(encode(newValue), forKey: "settings") }
	}
}

extension Core {

	static func load(slot: Int = UserDefaults.standard.slot) -> Core {
		UserDefaults.standard.load(slot: slot)
	}

	func save() {
		UserDefaults.standard.save(self)
	}
}
