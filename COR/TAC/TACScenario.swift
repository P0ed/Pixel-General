/// Complete, reusable recipe for a tactical battle.
public struct Scenario {
	public static var spawnOptions: [5 of XY] {
		[XY(1, 0), XY(1, 3), XY(3, 1), XY(0, 1), XY(1, 1)]
	}

	public var players: [Player]
	public var units: [Unit]
	public var terrain: [16 of Terrain]
	public var spawns: [4 of XY?]
	public var cityLevel: Int
	public var fortLevel: Int
	public var seed: Int
	public var objective: Objective

	public init(
		players: [Player],
		units: [Unit],
		terrain: [16 of Terrain] = .init(repeating: .field),
		spawns: [4 of XY?] = .init(repeating: nil),
		cityLevel: Int = 0,
		fortLevel: Int = 0,
		seed: Int = 0,
		objective: Objective = .none
	) {
		self.players = players
		self.units = Self.addingNavalAux(to: units, for: players, terrain: terrain)
		self.terrain = terrain
		self.spawns = spawns
		self.cityLevel = cityLevel
		self.fortLevel = fortLevel
		self.seed = seed
		self.objective = objective
	}

	public func makeSim() -> TacticalSim { TacticalSim(new: self) }

	private static func addingNavalAux(
		to units: [Unit],
		for players: [Player],
		terrain: [16 of Terrain]
	) -> [Unit] {
		let seaTiles = terrain.reduce(into: 0) { r, t in r += t == .sea ? 1 : 0 }
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

	public static func cornerTerrain(seaLevel: UInt8, seed: Int) -> [16 of Terrain] {
		var terrain = [16 of Terrain](repeating: .field)
		guard seaLevel > 0 else { return terrain }

		var d20 = D20(seed: seed)
		let tiles: [Int] = switch d20() {
		case ..<5: [3, 2, 7, 1, 0] // north-east
		case ..<10: [0, 1, 4, 2, 3] // north-west
		case ..<15: [12, 13, 8, 14, 15] // south-west
		default: [15, 14, 11, 13, 12] // south-east
		}
		let count = [0, 2, 3, 5][Int(min(seaLevel, 3))]
		for index in tiles.prefix(count) {
			terrain[index] = .sea
		}
		return terrain
	}

	var resolvedSpawnPoints: [XY] {
		var d20 = D20(seed: seed)
		var pool = Array(Self.spawnOptions).filter { option in
			!players.indices.contains { i in players[i].alive && spawns[i] == option }
		}
		.shuffled(using: &d20)

		var resolved: [XY] = []
		for idx in players.indices where players[idx].alive {
			if let xy = spawns[idx] {
				resolved.append(xy)
			} else {
				resolved.append(pool.removeFirst())
			}
		}

		return resolved
	}
}

extension XY {
	init(terrainIndex: Int) {
		self.init(terrainIndex % 4, 3 - terrainIndex / 4)
	}

	var terrainIndex: Int {
		(3 - y) * 4 + x
	}
}

public extension XY {

	/// Tactical-map center of a 4×4 terrain cell given its column and
	/// row from the south, both in 0…3.
	func cellCenter(size: Int) -> XY {
		let width = size / 4
		return XY(x * width + width / 2, y * width + width / 2)
	}
}

public extension TacticalSim {

	/// Non-auxiliary survivors of `country`, reset for the HQ roster.
	func survivingRoster(for country: Country) -> [16 of Unit] {
		let survivors: [Unit] = units.compactMapAlive { _, unit in
			unit.country != country || unit[.aux] ? nil : modifying(unit) { unit in
				unit.reset()
			}
		}
		return [16 of Unit](head: Array(survivors.prefix(16)), tail: .empty)
	}
}
