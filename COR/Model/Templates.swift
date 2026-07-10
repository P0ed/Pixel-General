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

	/// Campaign aux army shaped by the country's factory totals (each clamped
	/// 0...4): `army` fields infantry and artillery, `armor` vehicles, `air`
	/// aircraft, `aa` flak; a total of 3+ makes that class veteran. Capped at
	/// 16 units. Scenario battles keep the fixed `aux(_:tier:)` template.
	static func aux(
		_ country: Country,
		tier: UInt8 = 3,
		army: Int,
		armor: Int,
		air: Int,
		aa: Int
	) -> [Unit] {
		let shop = Shop(country: country, tier: tier)
		let army = Swift.min(Swift.max(army, 0), 4)
		let armor = Swift.min(Swift.max(armor, 0), 4)
		let air = Swift.min(Swift.max(air, 0), 4)
		let aa = Swift.min(Swift.max(aa, 0), 4)

		var units: [Unit?] = [Unit(model: .truck, country: country)]
		if army + armor >= 4 {
			units.append(Unit(model: .truck, country: country))
		}

		func add(_ total: Int, from cycle: [Unit?]) {
			for i in 0 ..< total {
				let u = cycle[i % cycle.count]
				units.append(total >= 3 ? u?.veteran : u)
			}
		}

		add(army, from: [shop.inf1, shop.inf2])
		if army >= 2 { units.append(army >= 3 ? shop.art1?.veteran : shop.art1) }
		if army >= 3 { units.append(shop.art2?.veteran) }
		add(armor, from: [shop.ifv1, shop.tank1, shop.ifv2, shop.tank2])
		add(air, from: [shop.air1, shop.air2])
		add(aa, from: [shop.aa1, shop.aa2])

		return Array(units.compactMap { u in u?.aux }.prefix(16))
	}

	static func aux(_ country: Country, tier: UInt8 = 3, lvl: UInt8 = 0) -> [Unit] {
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

		return units.compactMap { u in u?.aux.lvl(lvl) }
	}
}
