import Foundation
import COR

extension UserDefaults {

	enum Slot {
		case auto, main
	}

	func load(slot: Slot) -> Core {
		UserDefaults.standard.data(
			forKey: slot == .auto ? "auto" : "main"
		).flatMap { data in
			decode(data) as Core?
		} ?? .new(country: .default)
	}

	func save(_ state: borrowing Core, in slot: Slot) {
		UserDefaults.standard.set(
			encode(state),
			forKey: slot == .auto ? "auto" : "main"
		)
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
