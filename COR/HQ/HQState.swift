public struct HQSim: ~Copyable {
	public var map: Map<4, Terrain>
	public var player: Player
	public var units: [16 of Unit]
	/// Campaign army being edited. Meaningful only while Core has a campaign.
	public var army: Int

	public init(
		map: consuming Map<4, Terrain> = Map<4, Terrain>(zero: .field),
		player: Player,
		units: [16 of Unit],
		army: Int = 0
	) {
		self.map = map
		self.player = player
		self.units = units
		self.army = army
	}
}

public extension HQSim {

	var country: Country { player.country }

	var shop: [Unit] { Shop(country: country, tier: player.tier).units }

	/// Upgrade options for the unit occupying `xy`. Empty when the slot is
	/// vacant or the unit's family offers nothing else at the current tier.
	func upgrades(at xy: XY) -> [Unit] {
		guard let (_, unit) = units[xy] else { return [] }
		return Shop(country: country, tier: player.tier).upgrades(for: unit)
	}
}
