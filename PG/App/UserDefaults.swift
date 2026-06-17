import Foundation
import COR

extension UserDefaults {

	enum Slot {
		case auto, main
	}

	func load(slot: Slot) -> Core {
		data(
			forKey: slot == .auto ? "auto" : "main"
		).flatMap { data in
			decode(data) as Core?
		} ?? .new(country: .default)
	}

	func save(_ state: borrowing Core, in slot: Slot) {
		set(
			encode(state),
			forKey: slot == .auto ? "auto" : "main"
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

	static func load(auto: Bool) -> Core {
		UserDefaults.standard.load(slot: auto ? .auto : .main)
	}

	func save(auto: Bool) {
		UserDefaults.standard.save(self, in: auto ? .auto : .main)
	}
}
