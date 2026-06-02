public struct HQState: ~Copyable {
	public var map: Map<4, Terrain>
	public var player: Player
	public var units: [16 of Unit]
	public var events: CArray<16, HQEvent>
	public var cursor: XY
	public var selected: UID

	public init(
		map: consuming Map<4, Terrain> = Map<4, Terrain>(size: 4, zero: .field),
		player: Player,
		units: [16 of Unit],
		events: CArray<16, HQEvent> = .init(tail: .menu),
		cursor: XY = .zero,
		selected: UID = .none
	) {
		self.map = map
		self.player = player
		self.units = units
		self.events = events
		self.cursor = cursor
		self.selected = selected
	}
}

public extension HQState {

	var country: Country { player.country }

	var shop: [Unit] { .shop(country: country) }
}
