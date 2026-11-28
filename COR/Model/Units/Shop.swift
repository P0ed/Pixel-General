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
		let offers: [Unit?] = [
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
			tank4,

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
		return stocked(offers)
	}

	internal var navalUnits: [Unit] {
		stocked([nav1, nav2, nav3])
	}

	private func stocked(_ offers: [Unit?]) -> [Unit] {
		offers.compactMap { offer in
			offer.flatMap { unit in
				filter(unit) ? modifying(unit) { $0.ammo = $0.maxAmmo } : nil
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
			[tank1, tank2, tank3, tank4],
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
