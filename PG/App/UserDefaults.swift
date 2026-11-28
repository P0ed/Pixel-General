import Foundation
import COR

extension UserDefaults {

	private static var version: Int { 2 }

	var version: Int {
		get { integer(forKey: "version") }
		set { set(newValue, forKey: "version") }
	}

	var slot: Int {
		get { integer(forKey: "slot") }
		set { set(newValue, forKey: "slot") }
	}

	func load(slot: Int) -> Core {
		if version != Self.version {
			#bundle.bundleIdentifier.map(removePersistentDomain)
			version = Self.version
		}
		self.slot = slot
		return data(forKey: "slot-\(slot)").flatMap { data in decode(data) }
			?? .new(country: .default)
	}

	func save(_ state: borrowing Core) {
		set(
			encode(state),
			forKey: "slot-\(slot)"
		)
	}

	var settings: Settings {
		get { data(forKey: "settings").flatMap(decode) ?? Settings() }
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
