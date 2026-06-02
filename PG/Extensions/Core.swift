import Foundation
import COR

extension Core {

	static func load(auto: Bool) -> Core {
		if let data = UserDefaults.standard.data(forKey: auto ? "auto" : "main"),
		   let decoded = decode(data) as Core? {
			decoded
		} else {
			.new(country: .default)
		}
	}

	func save(auto: Bool) {
		UserDefaults.standard.set(encode(self), forKey: auto ? "auto" : "main")
	}
}
