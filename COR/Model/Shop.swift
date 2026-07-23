public struct Shop {
	var country: Country
	var tier: UInt8
	var air: Bool?
	/// Factory-type bitmask (bit = `BuildingType.rawValue`): a unit is offered
	/// only when its factory's bit is set. `0xFF` opens every class.
	var factories: UInt8

	public init(country: Country, tier: UInt8, air: Bool? = nil, factories: UInt8 = 0xFF) {
		self.country = country
		self.air = air
		self.tier = tier
		self.factories = factories
	}
}

extension Shop {

	func filter(_ unit: Unit) -> Bool {
		if let air, unit.isAir != air {
			false
		} else if unit.tier > tier {
			false
		} else if let factory = unit.factory, factories & 1 << factory.rawValue == 0 {
			false
		} else {
			true
		}
	}
}

extension Unit {

	var factory: BuildingType? {
		switch type {
		case .supply: nil
		case .inf, .art: .army
		case .wheelArt, .trackArt, .wheelAA, .trackAA,
			 .lightWheel, .lightTrack, .heavyTrack: .armor
		case .aa: .aa
		case .heli, .fighter, .cas: .air
		case .cargo, .destroyer, .cruiser: .navy
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
			fpv1,
			fpv2,

			recon1,
			ifv1,
			ifv2,
			ifv3,

			tank1,
			tank2,
			tank3,

			art1,
			art2,
			art3,

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

public extension Shop {

	private var families: [[Unit?]] {
		[
			[inf1, inf2, inf3],
			[fpv1, fpv2],
			[recon1, ifv1, ifv2, ifv3],
			[tank1, tank2, tank3],
			[art1, art2],
			[aa1, aa2, aa3],
			[air1, air2, air3, air4],
		]
	}

	/// Models `unit` may upgrade into: the other members of its family that the
	/// current tier unlocks, ammo topped up for the new platform to match
	/// `units`. The unit's own model — and any tier-locked sibling — is omitted.
	/// Returns `[]` when the unit has no family (supply) or no unlocked sibling.
	func upgrades(for unit: Unit) -> [Unit] {
		guard let family = families.first(where: { fam in
			fam.contains { $0?.model == unit.model }
		}) else { return [] }

		return family.compactMap { (slot: Unit?) -> Unit? in
			slot.flatMap { u in
				u.model != unit.model && filter(u)
					? modifying(u) { u in u.ammo = u.maxAmmo }
					: nil
			}
		}
	}
}
