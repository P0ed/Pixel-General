import Foundation
import COR

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
		get { data(forKey: "settings").flatMap(decode) ?? Settings() }
		set { set(encode(newValue), forKey: "settings") }
	}

	var lanHost: Address {
		get { string(forKey: "lanHost").flatMap(Address.init) ?? .default }
		set { set(newValue.string, forKey: "lanHost") }
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
