public struct Shop {
	var country: Country
	var filter: UnitsFilter = .none

	public init(country: Country, filter: UnitsFilter = .none) {
		self.country = country
		self.filter = filter
	}
}

public struct UnitsFilter {
	var air: Bool?
	var tier: UInt8?

	func predicate(_ unit: Unit) -> Bool {
		if let air, unit.isAir != air {
			false
		} else if let tier, unit.tier > tier {
			false
		} else {
			true
		}
	}
}

public extension UnitsFilter {
	static var none: UnitsFilter { .init() }
	static var air: UnitsFilter { .init(air: true) }
	static var land: UnitsFilter { .init(air: false) }
}

public extension Shop {

	var units: [Unit] {
		[
			.truck,

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
			u.flatMap { filter.predicate($0) ? $0.country(country) : nil }
		}
	}
}
