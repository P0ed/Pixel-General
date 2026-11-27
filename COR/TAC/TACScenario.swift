/// Complete, reusable recipe for a tactical battle.
public struct Scenario {
	public static var spawnOptions: [4 of XY] {
		[XY(0, 3), XY(3, 3), XY(0, 0), XY(3, 0)]
	}

	public var players: [Player] {
		didSet {
			if !symmetryAvailable { symmetry = false }
			for i in spawns.indices where !players.indices.contains(i) || !players[i].alive {
				spawns[i] = nil
			}
		}
	}
	public var units: [Unit]
	public var terrain: Terrain
	public var symmetry: Bool {
		didSet { if !symmetryAvailable { symmetry = false } }
	}
	public var mapType: MapType
	public var spawns: [4 of XY?]
	public var cityLevel: Int
	public var fortLevel: Int
	public var seed: Int
	public var objective: Objective

	public var symmetryAvailable: Bool { players.count(where: { $0.alive }) != 3 }

	public init(
		players: [Player],
		units: [Unit],
		terrain: Terrain = .field,
		spawns: [4 of XY?] = .init(repeating: nil),
		cityLevel: Int = 0,
		fortLevel: Int = 0,
		seed: Int = 0,
		objective: Objective = .none,
		symmetry: Bool = false,
		mapType: MapType = .land
	) {
		self.players = players
		self.units = units
		self.terrain = terrain
		self.symmetry = symmetry && players.count(where: { $0.alive }) != 3
		self.mapType = mapType
		self.spawns = .init { players.indices.contains($0) && players[$0].alive ? spawns[$0] : nil }
		self.cityLevel = cityLevel
		self.fortLevel = fortLevel
		self.seed = seed
		self.objective = objective
	}

	public func makeSim() -> TacticalSim { TacticalSim(new: self) }

	public func availableSpawns(for seat: Int) -> [XY] {
		Array(Self.spawnOptions).filter { option in
			!players.indices.contains { i in i != seat && players[i].alive && spawns[i] == option }
		}
	}

	var startingUnits: [Unit] {
		let active = players.filter { $0.alive }
		let countries = Set(active.map(\.country))
		var coreCounts: [Country: Int] = [:]
		let roster = units.filter { unit in
			guard countries.contains(unit.country) else { return false }
			if unit[.aux] { return true }
			guard coreCounts[unit.country, default: 0] < TacticalSim.coreUnitLimit else { return false }
			coreCounts[unit.country, default: 0] += 1
			return true
		}
		let fleet: [UnitModel] = mapType != .land ? [.cruiser, .destroyer, .destroyer, .cargo, .cargo] : []
		return Self.fittingAux(to: roster, for: active, fleet: fleet)
	}

	private static func fittingAux(
		to units: [Unit],
		for players: [Player],
		fleet: [UnitModel]
	) -> [Unit] {
		var result = units
		let desiredCounts = Dictionary(fleet.map { ($0, 1) }, uniquingKeysWith: +)
		for player in players {
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

			let total = result.count { $0.country == player.country } + additions.count
			var overflow = max(0, total - TacticalSim.totalUnitLimit)
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

	var resolvedSpawnPoints: [XY] {
		var d20 = D20(seed: seed)
		var pool = Array(Self.spawnOptions)
		let selected: [XY?] = players.indices.filter { players[$0].alive }.map { i in
			guard let pick = spawns[i], let index = pool.firstIndex(of: pick) else { return nil }
			return pool.remove(at: index)
		}
		pool.shuffle(using: &d20)
		return selected.map { $0 ?? pool.removeFirst() }
	}

	static var quarterCity: XY { XY(8, 8) }
	static var quarterAirfield: XY { XY(8, 9) }

	static func inCorner(_ corner: XY, tile: XY) -> XY {
		XY(corner.x == 0 ? tile.x : 63 - tile.x, corner.y == 0 ? tile.y : 63 - tile.y)
	}
}

public enum MapType: UInt8, CaseIterable, Sendable {
	case land, island, twoIslands, fourIslands
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
		return [16 of Unit](head: Array(survivors.prefix(Self.coreUnitLimit)), tail: .empty)
	}
}
