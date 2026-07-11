public struct HQSim: ~Copyable {
	public var map: Map<4, Terrain>
	public var player: Player
	public var units: [16 of Unit]

	public init(
		map: consuming Map<4, Terrain> = Map<4, Terrain>(size: 4, zero: .field),
		player: Player,
		units: [16 of Unit]
	) {
		self.map = map
		self.player = player
		self.units = units
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
