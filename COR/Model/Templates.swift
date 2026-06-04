public extension [Unit] {

	static func shop(country: Country, filterAir: Bool? = nil) -> [Unit] {
		let ground: [Unit?] = filterAir == true ? [] : [
			.truck,
			.inf(country),
			.inf2(country),
			.inf3(country),

			.recon1(country),
			.ifv1(country),
			.ifv2(country),
			.tank(country),

			.tank2(country),
			.tank3(country),
			.art(country),
			.art2(country),

			.aa(country),
			.aa2(country),
			.aa3(country),
		]

		let air: [Unit?] = filterAir == false ? [] : [
			.air(country),
			.air2(country),
			.air3(country),
			.air4(country),
		]

		return (ground + air).compactMap { u in u?.country(country) }
	}

	static func base(_ country: Country) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.regular,
			.regular,
			.regular.veteran,

			.regular.veteran,
			.tank(country),
			.tank(country).veteran,
			.tank2(country).veteran,

			.ifv1(country),
			.ifv1(country).veteran,
			.art(country).veteran,
			.art(country).veteran,

			.art2(country).veteran,
			.art2(country).veteran,
			.aa(country).veteran,
			.aa(country).veteran,
		]

		return units.compactMap { u in u?.country(country) }
	}

	static func small(_ country: Country) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.regular.veteran,
			.regular.veteran,
			.tank(country).veteran,
			.ifv1(country).veteran,
			.art(country).veteran,
			.aa(country).veteran,
		]

		return units.compactMap { u in u?.country(country) }
	}

	static func aux(country: Country) -> [Unit] {
		let units: [Unit?] = [
			.truck,
			.truck,
			.inf(country),
			.inf(country),

			.inf2(country),
			.ifv1(country),
			.tank(country),
			.tank(country),

			.inf2(country),
			.ifv2(country),
			.air(country),
			.air2(country),

			.art(country),
			.art(country),
			.aa(country),
			.aa(country),
		]

		return units.compactMap { u in u?.country(country).traits(.aux) }
	}
}
