extension [Unit] {

	static func template(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: .zero, stats: .base >< .truck),
			Unit(country: country, position: .zero, stats: .base >< .inf(country)),
			Unit(country: country, position: .zero, stats: .base >< .inf2(country)),
			Unit(country: country, position: .zero, stats: .base >< .ifv(country)),
			Unit(country: country, position: .zero, stats: .base >< .ifv2(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank(country)),
			Unit(country: country, position: .zero, stats: .base >< .tank2(country)),
			Unit(country: country, position: .zero, stats: .base >< .art(country)),
			Unit(country: country, position: .zero, stats: .base >< .art2(country)),
			Unit(country: country, position: .zero, stats: .base >< .aa(country)),
			Unit(country: country, position: .zero, stats: .base >< .heli(country)),
			Unit(country: country, position: .zero, stats: .base >< .fighter(country)),
		]
	}

	static func base(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: XY(0, 0), stats: .base >< .truck),
			Unit(country: country, position: XY(1, 0), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(2, 0), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(0, 1), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(1, 1), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(2, 1), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(0, 2), stats: .base >< .ifv(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .art(country) >< .veteran),
			Unit(country: country, position: XY(2, 2), stats: .base >< .art(country) >< .veteran),
		]
	}

	static func small(_ country: Country) -> [Unit] {
		[
			Unit(country: country, position: XY(0, 0), stats: .base >< .truck),
			Unit(country: country, position: XY(0, 1), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(2, 0), stats: .base >< .regular >< .veteran),
			Unit(country: country, position: XY(0, 2), stats: .base >< .tank(country) >< .veteran),
			Unit(country: country, position: XY(1, 0), stats: .base >< .ifv(country) >< .veteran),
			Unit(country: country, position: XY(1, 2), stats: .base >< .art(country) >< .veteran),
			Unit(country: country, position: XY(2, 2), stats: .base >< .aa(country) >< .veteran),
		]
	}
}
