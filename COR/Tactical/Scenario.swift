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
		TacticalSim(
			players: players,
			units: units,
			size: size,
			seed: seed,
			terrain: terrain,
			objective: objective,
			forts: fortLevel,
			buildingsMask: buildingsMask
		)
	}

	/// Field neighborhood with zero to three cumulative sea squares in a
	/// corner. The canonical north-east pattern is:
	///
	///     L 2 1
	///     L L 3
	///     L L L
	///
	/// A seeded draw rotates that pattern to one of the four corners, keeping
	/// replays deterministic while varying standalone scenario coastlines.
	public static func cornerTerrain(seaLevel: UInt8, seed: Int) -> [9 of Terrain] {
		var terrain = [9 of Terrain](repeating: .field)
		guard seaLevel > 0 else { return terrain }

		var d20 = D20(seed: UInt64(bitPattern: Int64(seed)))
		let tiles: [Int] = switch Int.random(in: 0 ..< 4, using: &d20) {
		case 0: [2, 1, 5] // north-east
		case 1: [0, 1, 3] // north-west
		case 2: [6, 7, 3] // south-west
		default: [8, 7, 5] // south-east
		}
		for index in tiles.prefix(Int(min(seaLevel, 3))) {
			terrain[index] = .sea
		}
		return terrain
	}
}
