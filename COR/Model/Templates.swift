public extension [Unit] {

	static func base(_ country: Country, lvl: UInt8 = 0) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.regular,
			.regular,
			.regular.veteran,

			.regular.veteran,
			.tank1(country),
			.tank1(country).veteran,
			.tank2(country).veteran,

			.ifv1(country),
			.ifv1(country).veteran,
			.art1(country).veteran,
			.art1(country).veteran,

			.art2(country).veteran,
			.art2(country).veteran,
			.aa1(country).veteran,
			.aa1(country).veteran,
		]

		return units.compactMap { u in
			u?.country(country).lvl(lvl + (u?.lvl ?? 0))
		}
	}

	static func small(_ country: Country) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.regular.veteran,
			.regular.veteran,
			.tank1(country).veteran,
			.ifv1(country).veteran,
			.art1(country).veteran,
			.aa1(country).veteran,
		]

		return units.compactMap { u in u?.country(country) }
	}

	static func aux(_ country: Country) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.truck,
			.inf1(country),
			.inf1(country),

			.inf2(country),
			.inf2(country),
			.ifv1(country),
			.ifv2(country),

			.tank1(country),
			.tank2(country),
			.air1(country),
			.air2(country),

			.art1(country),
			.art2(country),
			.aa1(country),
			.aa2(country),
		]

		return units.compactMap { u in
			u?.country(country).traits(.aux)
		}
	}
}
