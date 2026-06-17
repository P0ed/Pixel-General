/// Deterministic HQ simulation state — the roster, economy, and the reducer.
/// Owns everything `reduce` may touch; by construction it cannot reference UI.
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

	var shop: [Unit] { Shop(country: country).units }
}

/// Presentation-only HQ state. Never read by `reduce`; may diverge per peer.
public struct HQUI {
	public var cursor: XY
	public var selected: UID

	public init(cursor: XY = .zero, selected: UID = .none) {
		self.cursor = cursor
		self.selected = selected
	}
}

public struct HQState: ~Copyable {
	public var sim: HQSim
	public var ui: HQUI

	public init(sim: consuming HQSim, ui: HQUI = HQUI()) {
		self.sim = sim
		self.ui = ui
	}
}
