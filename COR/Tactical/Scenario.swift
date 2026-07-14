/// Complete, reusable recipe for a tactical battle. Campaign code builds a
/// scenario from strategic state; trainers and auto-resolution can consume the
/// same value without constructing a full simulation first.
public struct Scenario {
	public var players: [Player]
	public var units: [Unit]
	/// Strategic 3×3 neighborhood, row-major north-west to south-east. The
	/// attacker occupies index 3 and the defender index 4.
	public var terrain: [9 of Terrain]
	public var fortLevel: Int
	public var size: Int
	public var seed: Int
	public var objective: Objective
	public var buildingsMask: [4 of UInt8]

	public init(
		players: [Player],
		units: [Unit],
		terrain: [9 of Terrain] = .init(repeating: .field),
		fortLevel: Int = 0,
		size: Int = 24,
		seed: Int = 0,
		objective: Objective = .none,
		buildingsMask: [4 of UInt8] = .init(repeating: 0xFF)
	) {
		self.players = players
		self.units = units
		self.terrain = terrain
		self.fortLevel = fortLevel
		self.size = size
		self.seed = seed
		self.objective = objective
		self.buildingsMask = buildingsMask
	}

	public func makeSim() -> TacticalSim {
		TacticalSim(self)
	}
}

public extension TacticalSim {

	init(_ scenario: borrowing Scenario) {
		self.init(
			players: scenario.players,
			units: scenario.units,
			size: scenario.size,
			seed: scenario.seed,
			terrain: scenario.terrain,
			objective: scenario.objective,
			forts: scenario.fortLevel,
			buildingsMask: scenario.buildingsMask
		)
	}
}
