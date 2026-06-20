public struct Shop {
	var country: Country
	var air: Bool?
	var tier: UInt8

	public init(country: Country, air: Bool? = nil, tier: UInt8) {
		self.country = country
		self.air = air
		self.tier = tier
	}
}

extension Shop {

	func predicate(_ unit: Unit) -> Bool {
		if let air, unit.isAir != air {
			false
		} else if unit.tier > tier {
			false
		} else {
			true
		}
	}
}

public extension Shop {

	var units: [Unit] {
		[
			Unit(model: .truck, country: country),

			.inf1(country),
			.inf2(country),
			.inf3(country),

			.recon1(country),

			.ifv1(country),
			.ifv2(country),

			.tank1(country),
			.tank2(country),
			.tank3(country),

			.art1(country),
			.art2(country),

			.aa1(country),
			.aa2(country),
			.aa3(country),

			.air1(country),
			.air2(country),
			.air3(country),
			.air4(country),
		]
		.compactMap { (u: Unit?) -> Unit? in
			u.flatMap { predicate($0) ? $0 : nil }
		}
	}
}
