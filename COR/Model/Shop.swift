public struct Shop {
	var country: Country
	var tier: UInt8
	var air: Bool?

	public init(country: Country, tier: UInt8, air: Bool? = nil) {
		self.country = country
		self.air = air
		self.tier = tier
	}
}

extension Shop {

	func filter(_ unit: Unit) -> Bool {
		if let air, unit.isAir != air {
			false
		} else if unit.tier > tier {
			false
		} else {
			true
		}
	}
}

public extension Shop {

	var units: [Unit] {
		[
			Unit(model: .truck, country: country),

			inf1,
			inf2,
			inf3,

			recon1,
			recon2,

			ifv1,
			ifv2,

			tank1,
			tank2,
			tank3,

			art1,
			art2,

			aa1,
			aa2,
			aa3,

			air1,
			air2,
			air3,
			air4,
		]
		.compactMap { (u: Unit?) -> Unit? in
			u.flatMap {
				!filter($0) ? nil : modifying($0) { u in u.ammo = u.maxAmmo }
			}
		}
	}
}
