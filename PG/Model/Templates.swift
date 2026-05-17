extension [Unit] {

	static func shop(country: Country, filterAir: Bool? = nil) -> [Unit] {
		let ground: [Unit] = [
			.truck,
			.inf(country),
			.inf2(country),
			.ifv(country),
			.ifv2(country),
			.tank(country),
			.tank2(country),
			.art(country),
			.art2(country),
			.aa(country),
		]
		let air: [Unit] = [
			.heli(country),
			.fighter(country),
			.air(country),
		]
		let units = (filterAir.map { $0 ? air : ground } ?? ground + air)
		return units.map { (u: Unit) -> Unit in
			u.country(country)
		}
	}

	static func base(_ country: Country) -> [Unit] {
		[
			.truck,
			.regular.veteran,
			.regular.veteran,
			.regular.veteran,
			.tank(country).veteran,
			.tank(country).veteran,
			.ifv(country).veteran,
			.art(country).veteran,
			.art(country).veteran,
		].map { (u: Unit) -> Unit in
			u.country(country)
		}
	}

	static func small(_ country: Country) -> [Unit] {
		[
			.truck,
			.regular.veteran,
			.regular.veteran,
			.tank(country).veteran,
			.ifv(country).veteran,
			.art(country).veteran,
			.aa(country).veteran,
		].map { (u: Unit) -> Unit in
			u.country(country)
		}
	}

	static func aux(country: Country) -> [Unit] {
		[
			.truck,
			.truck,
			.inf(country),
			.inf(country),

			.inf2(country),
			.ifv(country),
			.tank(country),
			.tank(country),

			.inf2(country),
			.ifv2(country),
			.heli(country),
			.heli(country),

			.art(country),
			.art(country),
			.aa(country),
			.aa(country),
		].map { (u: Unit) -> Unit in
			u.country(country).traits(.aux)
		}
	}
}
