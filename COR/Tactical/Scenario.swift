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
	public var seed: Int
	public var objective: Objective
	public var buildingsMask: [4 of UInt8]

	public init(
		players: [Player],
		units: [Unit],
		terrain: [9 of Terrain] = .init(repeating: .field),
		fortLevel: Int = 0,
		seed: Int = 0,
		objective: Objective = .none,
		buildingsMask: [4 of UInt8] = .init(repeating: 0xFF)
	) {
		self.players = players
		self.units = Self.addingNavalAux(to: units, for: players, terrain: terrain)
		self.terrain = terrain
		self.fortLevel = fortLevel
		self.seed = seed
		self.objective = objective
		self.buildingsMask = buildingsMask
	}

	public func makeSim() -> TacticalSim {
		TacticalSim(
			players: players,
			units: units,
			seed: seed,
			terrain: terrain,
			objective: objective,
			forts: fortLevel,
			buildingsMask: buildingsMask
		)
	}

	/// A coastline large enough to field ships grants every participating
	/// country a five-ship auxiliary fleet: one cruiser, two destroyers, and two
	/// cargo ships. Existing non-fleet aux slots are replaced as needed to keep
	/// the force at its 16-unit cap so four full rosters still fit.
	private static func addingNavalAux(
		to units: [Unit],
		for players: [Player],
		terrain: [9 of Terrain]
	) -> [Unit] {
		var seaTiles = 0
		for i in terrain.indices where terrain[i] == .sea { seaTiles += 1 }
		guard seaTiles >= 3 else { return units }

		var result = units
		let fleet: [UnitModel] = [.cruiser, .destroyer, .destroyer, .cargo, .cargo]
		let desiredCounts = Dictionary(fleet.map { ($0, 1) }, uniquingKeysWith: +)
		for player in players where player.alive {
			let isAux = { (unit: Unit) in
				unit.country == player.country && unit[.aux]
			}
			let level = result.first(where: isAux)?.lvl ?? player.baseLevel
			var currentCounts = Dictionary(
				result.filter(isAux).map { ($0.model, 1) },
				uniquingKeysWith: +
			)
			var available = currentCounts
			let additions = fleet.compactMap { model -> UnitModel? in
				if available[model, default: 0] > 0 {
					available[model, default: 0] -= 1
					return nil
				}
				return model
			}

			var overflow = max(0, result.count(where: isAux) + additions.count - 16)
			while overflow > 0, let last = result.lastIndex(where: { unit in
				isAux(unit) && currentCounts[unit.model, default: 0] > desiredCounts[unit.model, default: 0]
			}) {
				currentCounts[result[last].model, default: 0] -= 1
				result.remove(at: last)
				overflow -= 1
			}
			for model in additions {
				result.append(Unit(model: model, country: player.country).aux.lvl(level))
			}
		}
		return result
	}

	/// Field neighborhood with zero or two to four cumulative sea squares in
	/// a corner. The canonical north-east pattern is:
	///
	///     3 1 1
	///     L L 2
	///     L L L
	///
	/// A seeded draw rotates that pattern to one of the four corners, keeping
	/// replays deterministic while varying standalone scenario coastlines.
	public static func cornerTerrain(seaLevel: UInt8, seed: Int) -> [9 of Terrain] {
		var terrain = [9 of Terrain](repeating: .field)
		guard seaLevel > 0 else { return terrain }

		var d20 = D20(seed: UInt64(bitPattern: Int64(seed)))
		let tiles: [Int] = switch Int.random(in: 0 ..< 4, using: &d20) {
		case 0: [2, 1, 5, 0] // north-east
		case 1: [0, 1, 3, 2] // north-west
		case 2: [6, 7, 3, 8] // south-west
		default: [8, 7, 5, 2] // south-east
		}
		for index in tiles.prefix(Int(min(seaLevel + 1, 4))) {
			terrain[index] = .sea
		}
		return terrain
	}
}
