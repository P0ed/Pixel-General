/// Complete, reusable recipe for a tactical battle, shared by the app and
/// AI training tools.
public struct Scenario {
	public var players: [Player]
	public var units: [Unit]
	public var terrain: [9 of Terrain]
	public var spawns: [4 of XY?]
	public var cityLevel: Int
	public var fortLevel: Int
	public var seed: Int
	public var objective: Objective

	public init(
		players: [Player],
		units: [Unit],
		terrain: [9 of Terrain] = .init(repeating: .field),
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
		terrain: [9 of Terrain]
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

	public static func cornerTerrain(seaLevel: UInt8, seed: Int) -> [9 of Terrain] {
		var terrain = [9 of Terrain](repeating: .field)
		guard seaLevel > 0 else { return terrain }

		var d20 = D20(seed: seed)
		let tiles: [Int] = switch d20() {
		case ..<5: [2, 1, 5, 0] // north-east
		case ..<10: [0, 1, 3, 2] // north-west
		case ..<15: [6, 7, 3, 8] // south-west
		default: [8, 7, 5, 2] // south-east
		}
		for index in tiles.prefix(Int(min(seaLevel + 1, 4))) {
			terrain[index] = .sea
		}
		return terrain
	}

	var resolvedSpawnPoints: [XY] {
		let options: [5 of XY] = XY.one.c5
		var d20 = D20(seed: seed)
		var pool = Array(options).filter { option in
			!players.indices.contains { i in players[i].alive && spawns[i] == option }
		}
		.shuffled(using: &d20)

		var resolved: [XY] = []
		for idx in players.indices where players[idx].alive {
			if let xy = spawns[idx] {
				resolved.append(xy)
			} else {
				if pool.isEmpty { pool = Array(XY.one.x4) }
				resolved.append(pool.removeFirst())
			}
		}

		return resolved
	}
}

public extension XY {

	/// Tactical-map center of a 3×3 terrain cell; `self` is the cell as
	/// (column, row-from-south), each 0…2.
	func cellCenter(size: Int) -> XY {
		XY((x * 2 + 1) * size / 6, (y * 2 + 1) * size / 6)
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
