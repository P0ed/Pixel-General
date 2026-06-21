public extension [Unit] {

	static func base(_ country: Country, lvl: UInt8 = 0, tier: UInt8 = 3) -> [Unit] {
		let shop = Shop(country: country, tier: tier)
		let units: [Unit?] = [
			Unit(model: .truck, country: country),
			shop.inf1,
			shop.inf1,
			shop.inf1?.veteran,

			shop.inf1?.veteran,
			shop.tank1,
			shop.tank1?.veteran,
			shop.tank2?.veteran,

			shop.recon1,
			shop.ifv1?.veteran,
			shop.art1,
			shop.art1?.veteran,

			shop.art2,
			shop.art2?.veteran,
			shop.aa1,
			shop.aa1?.veteran,
		]

		return units.compactMap { u in
			u?.lvl(lvl + (u?.lvl ?? 0))
		}
	}

	static func small(_ country: Country, tier: UInt8 = 3) -> [Unit] {
		let shop = Shop(country: country, tier: tier)
		let units: [Unit?] = [
			Unit(model: .truck, country: country),
			shop.inf1,
			shop.inf1?.veteran,
			shop.tank1,
			shop.ifv1?.veteran,
			shop.art1?.veteran,
			shop.aa2?.veteran,
		]

		return units.compactMap { u in u }
	}

	static func aux(_ country: Country, tier: UInt8 = 3) -> [Unit] {
		let shop = Shop(country: country, tier: tier)
		let units: [Unit?] = [
			Unit(model: .truck, country: country),
			Unit(model: .truck, country: country),
			shop.inf1,
			shop.inf1,

			shop.inf2,
			shop.inf2,
			shop.ifv1,
			shop.ifv2,

			shop.tank1,
			shop.tank2,
			shop.air1,
			shop.air2,

			shop.art1,
			shop.art2,
			shop.aa1,
			shop.aa2,
		]

		return units.compactMap { u in u?.aux }
	}
}
