public struct TacticalSim: ~Copyable {
	public var map: Map<32, Terrain>
	public var control: Map<32, Country>
	public var unitsMap: Map<32, UID>
	/// The settlement tiles of `map`, indexed once at battle creation
	/// (`indexSettlements`) — the map never changes during a battle, only
	/// `control` does.
	public var settlements: SetXY = .empty

	public var players: CArray<4, Player>
	public var vision: [4 of SetXY]
	public var auxilia: [4 of CArray<16, Unit>]

	public var units: Speicher<128, Unit>
	public var position: [128 of XY]
	public var cargo: [128 of UID]

	public var turn: UInt32 = 0
	public var d20: D20 = D20()

	public var objective: Objective = .none
}

public struct TacticalUI: ~Copyable {
	public var cursor: XY = .zero
	public var camera: XY = .zero
	public var selectedUnit: UID = .none
	public var selectable: SetXY?
	public var scale: Int = 1
	public var mapMode: MapMode = .terrain

	public init() {}
}

public struct TacticalState: ~Copyable {
	public var sim: TacticalSim
	public var ui: TacticalUI

	public init(sim: consuming TacticalSim, ui: consuming TacticalUI = TacticalUI()) {
		self.sim = sim
		self.ui = ui
	}
}

@frozen public enum Objective: Equatable, BitwiseCopyable {
	case none
	case survive(Team, day: UInt16)
}

@frozen public enum MapMode: UInt8, Hashable {
	case terrain, supply, country, team
}

public extension TacticalSim {

	init(map: consuming Map<32, Terrain>, players: [Player], cities: [(XY, Country)], units: [Unit]) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.units = .init(head: units, tail: .empty)
		self.position = .init(repeating: .zero)
		vision = .init(repeating: .empty)
		cargo = .init(repeating: .none)
		unitsMap = .init(size: self.map.size, zero: .none)
		control = .init(size: self.map.size, zero: .default)
		auxilia = .init { i in
			CArray(
				head: i < players.count ? .aux(players[i].country) : [],
				tail: .empty
			)
		}
		indexSettlements()
		cities.forEach { xy, c in control[xy] = c }
		settlements.forEach { xy in
			guard self.map[xy].isVillage || self.map[xy] == .airfield else { return }
			control[xy] = cities.min { a, b in
				xy.manhattanDistance(to: a.0) < xy.manhattanDistance(to: b.0)
			}.map { $0.1 } ?? .default
		}
		assignControl()

		let placements = [4 of CArray<1024, XY>].init { i in
			guard i < players.count else { return .init(tail: .zero) }

			let cityXYs = cities
				.filter { _, c in c == players[i].country }
				.map { xy, _ in xy }
			let squares = (cityXYs.isEmpty ? [.zero] : cityXYs).map { $0.s49.map { $0 } }
			var out = CArray<1024, XY>(tail: .zero)
			var cursors = [Int](repeating: 0, count: squares.count)
			var progressed = true
			while progressed {
				progressed = false
				for k in squares.indices where cursors[k] < squares[k].count {
					out.add(squares[k][cursors[k]])
					cursors[k] += 1
					progressed = true
				}
			}
			return out
		}
		var allocatedUnits = [0, 0, 0, 0] as [4 of Int]

		for i in self.units.indices where self.units[i].alive {
			let u = self.units[i]
			guard let player = players.firstIndex(where: { p in p.country == u.country })
			else { continue }

			var k = allocatedUnits[player]
			while k < placements[player].count {
				let xy = placements[player][k]
				if self.map.contains(xy), unitsMap[xy] == .none, !self.map[xy].isRiver {
					break
				}
				k += 1
			}
			guard k < placements[player].count else { fatalError() }

			place(i.uid, at: placements[player][k])
			allocatedUnits[player] = k + 1
		}

		let v = self.players.map { i, p in vision(for: p.country) }
		self.players.modifyEach { i, p in vision[i] = v[i] }
	}

	subscript(_ xy: XY) -> Unit? {
		get {
			let idx = unitsMap[xy].index
			return if idx < 0 { nil } else { units[idx] }
		}
	}

	subscript(_ country: Country) -> Player {
		_read {
			if let idx = players.firstMap({ i, p in p.country == country ? i : nil }) {
				yield players[idx]
			} else {
				fatalError()
			}
		}
		_modify {
			if let idx = players.firstMap({ i, p in p.country == country ? i : nil }) {
				yield &players[idx]
			} else {
				fatalError()
			}
		}
	}

	/// Rebuilds the settlement index from `map`. Called by the battle
	/// constructors; anything that mutates `map` afterwards (nothing does
	/// today) must call it again.
	mutating func indexSettlements() {
		settlements = .empty
		for xy in map.indices where map[xy].isSettlement {
			settlements[xy] = true
		}
	}

	func hasBuildings(near id: UID) -> Bool {
		let u = units[id]
		return position[id.index].c5.contains { xy in
			map[xy].isSettlement
			&& control[xy] == u.country
			&& (map[xy] == .airfield) == u.isAir
		}
	}

	func vision(for id: UID) -> SetXY {
		vision(at: position[id], spot: units[id].spot)
	}

	func vision(at pos: XY, spot: UInt8) -> SetXY {
		.make { v in
			v[pos] = true
			switch spot {
			case 3: pos.n36.forEach { xy in v[xy] = true }
			default: pos.n20.forEach { xy in v[xy] = true }
			}
		}
	}

	func vision(for country: Country) -> SetXY {
		var v = units.reduceAlive(into: SetXY.empty) { v, i, u in
			if u.country.team == country.team { v.formUnion(vision(for: i.uid)) }
		}
		settlements.forEach { xy in
			guard control[xy].team == country.team else { return }
			v[xy] = true
			xy.n8.forEach { xy in v[xy] = true }
		}
		return v
	}

	func neighbors(at position: XY) -> CArray<8, UID> {
		let n8 = position.n8
		var result = CArray<8, UID>(tail: .none)
		for i in n8.indices {
			let uid = unitsMap[n8[i]]
			if uid != .none { result.add(uid) }
		}
		return result
	}

	var playerIndex: Int {
		Int(turn) % players.count
	}

	var player: Player {
		_read { yield players[playerIndex] }
		_modify { yield &players[playerIndex] }
	}

	var country: Country {
		player.country
	}

	func offMap(unit id: UID) -> Bool {
		unitsMap[position[id]] != id
	}

	func isVisible(_ id: UID) -> Bool {
		!offMap(unit: id) && vision[playerIndex][position[id]]
	}

	func isVisibleToHuman(_ id: UID) -> Bool {
		!offMap(unit: id) && isVisibleToHuman(position[id])
	}

	func isVisibleToHuman(_ xy: XY) -> Bool {
		players.indices.contains { i in players[i].type == .human && vision[i][xy] }
	}

	var visibleToHuman: SetXY {
		players.reduce(into: .empty) { r, i, p in
			p.type == .human ? r.combine(vision[i]) : ()
		}
	}
}
