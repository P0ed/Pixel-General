public struct Shop {
	var country: Country
	var filter: UnitsFilter = .none

	public init(country: Country, filter: UnitsFilter = .none) {
		self.country = country
		self.filter = filter
	}
}

public struct UnitsFilter {
	var predicate: (Unit) -> Bool
}

public extension UnitsFilter {
	static var none: UnitsFilter { .init { _ in true } }
	static var air: UnitsFilter { .init { u in u.isAir } }
	static var land: UnitsFilter { .init { u in !u.isAir } }
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
