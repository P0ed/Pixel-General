extension [Unit] {

	static func shop(country: Country, filterAir: Bool? = nil) -> [Unit] {
		let ground: [Unit] = [
			Unit(country: country) >< .truck,
			Unit(country: country) >< .inf(country),
			Unit(country: country) >< .inf2(country),
			Unit(country: country) >< .ifv(country),
			Unit(country: country) >< .ifv2(country),
			Unit(country: country) >< .tank(country),
			Unit(country: country) >< .tank2(country),
			Unit(country: country) >< .art(country),
			Unit(country: country) >< .art2(country),
			Unit(country: country) >< .aa(country),
		]
		let air: [Unit] = [
			Unit(country: country) >< .heli(country),
			Unit(country: country) >< .fighter(country),
		]
		return filterAir.map { $0 ? air : ground } ?? ground + air
	}

	static func base(_ country: Country) -> [Unit] {
		\.grid4x4 § [
			Unit(country: country) >< .truck,
			Unit(country: country) >< .regular >< .veteran,
			Unit(country: country) >< .regular >< .veteran,
			Unit(country: country) >< .regular >< .veteran,
			Unit(country: country) >< .tank(country) >< .veteran,
			Unit(country: country) >< .tank(country) >< .veteran,
			Unit(country: country) >< .ifv(country) >< .veteran,
			Unit(country: country) >< .art(country) >< .veteran,
			Unit(country: country) >< .art(country) >< .veteran,
		]
	}

	static func small(_ country: Country) -> [Unit] {
		\.grid4x4 § [
			Unit(country: country) >< .truck,
			Unit(country: country) >< .regular >< .veteran,
			Unit(country: country) >< .regular >< .veteran,
			Unit(country: country) >< .tank(country) >< .veteran,
			Unit(country: country) >< .ifv(country) >< .veteran,
			Unit(country: country) >< .art(country) >< .veteran,
			Unit(country: country) >< .aa(country) >< .veteran,
		]
	}

	var grid4x4: [Unit] {
		enumerated().map { i, u in
			modifying(u) { u in u.position = XY(i % 4, i / 4) }
		}
	}
}
