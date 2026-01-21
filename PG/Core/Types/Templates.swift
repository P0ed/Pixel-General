extension [Unit] {

	static func template(_ country: Country) -> [Unit] {
		[
			Unit(country: country) >< .base >< .truck,
			Unit(country: country) >< .base >< .inf(country),
			Unit(country: country) >< .base >< .inf2(country),
			Unit(country: country) >< .base >< .ifv(country),
			Unit(country: country) >< .base >< .ifv2(country),
			Unit(country: country) >< .base >< .tank(country),
			Unit(country: country) >< .base >< .tank2(country),
			Unit(country: country) >< .base >< .art(country),
			Unit(country: country) >< .base >< .art2(country),
			Unit(country: country) >< .base >< .aa(country),
			Unit(country: country) >< .base >< .heli(country),
			Unit(country: country) >< .base >< .fighter(country),
		]
	}

	static func base(_ country: Country) -> [Unit] {
		\.grid4x4 § [
			Unit(country: country) >< .base >< .truck,
			Unit(country: country) >< .base >< .regular >< .veteran,
			Unit(country: country) >< .base >< .regular >< .veteran,
			Unit(country: country) >< .base >< .regular >< .veteran,
			Unit(country: country) >< .base >< .tank(country) >< .veteran,
			Unit(country: country) >< .base >< .tank(country) >< .veteran,
			Unit(country: country) >< .base >< .ifv(country) >< .veteran,
			Unit(country: country) >< .base >< .art(country) >< .veteran,
			Unit(country: country) >< .base >< .art(country) >< .veteran,
		]
	}

	static func small(_ country: Country) -> [Unit] {
		\.grid4x4 § [
			Unit(country: country) >< .base >< .truck,
			Unit(country: country) >< .base >< .regular >< .veteran,
			Unit(country: country) >< .base >< .regular >< .veteran,
			Unit(country: country) >< .base >< .tank(country) >< .veteran,
			Unit(country: country) >< .base >< .ifv(country) >< .veteran,
			Unit(country: country) >< .base >< .art(country) >< .veteran,
			Unit(country: country) >< .base >< .aa(country) >< .veteran,
		]
	}

	var grid4x4: [Unit] {
		enumerated().map { i, u in
			modifying(u) { u in u.position = XY(i % 4, i / 4) }
		}
	}
}
