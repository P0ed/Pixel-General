public struct TacticalSim: ~Copyable {
	public var map: Map<64, Terrain>
	public var control: Map<64, Country>
	public var unitsMap: Map<64, UID>
	public var settlements: SetXY = .empty

	public var players: CArray<4, Player>
	public var vision: [4 of SetXY]

	public var units: Speicher<128, Unit>
	public var position: [128 of XY]
	public var cargo: [128 of UID]

	public var turn: UInt32 = 0
	public var d20: D20 = D20()

	public var objective: Objective = .none
}

@frozen public enum Objective: Equatable, BitwiseCopyable {
	case none
	case survive(Team, day: UInt16)

	public var defender: Team? {
		if case .survive(let team, _) = self { team } else { nil }
	}
}

public extension TacticalSim {

	init(
		map: consuming Map<64, Terrain>,
		players: [Player],
		cities: [(XY, Country)],
		units: [Unit],
		homes: [Country: XY] = [:],
		navalCenters: [Team: XY] = [:]
	) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.units = .init(head: units, tail: .empty)
		position = .init(repeating: .zero)
		vision = .init(repeating: .empty)
		cargo = .init(repeating: .none)
		unitsMap = .init(zero: .none)
		control = .init(zero: .none)
		indexSettlements()
		let cities = cities.filter { xy, _ in self.map[xy] == .city }
		cities.forEach { xy, c in control[xy] = c }
		assignControl()

		let tileCount = self.map.count
		let placements: [[XY]] = players.map { player in
			guard homes[player.country] == nil else { return [] }
			let cityXYs = cities
				.filter { _, c in c == player.country }
				.map { xy, _ in xy }
			let squares = (cityXYs.isEmpty ? [.zero] : cityXYs).map(\.s49)
			var out: [XY] = []
			for i in 0..<49 {
				for square in squares {
					if out.count == tileCount { return out }
					out.append(square[i])
				}
			}
			return out
		}
		var allocatedUnits = [0, 0, 0, 0] as [4 of Int]

		for i in self.units.indices where self.units[i].alive {
			let u = self.units[i]
			guard let player = players.firstIndex(where: { p in p.country == u.country })
			else { continue }
			if let home = homes[u.country] {
				let nearby = u.type.isNaval ? nil : home.s49.firstMap { canDeploy(u, at: $0) ? $0 : nil }
				guard let xy = nearby ?? nearestPlacement(for: u, near: home) else { fatalError() }
				place(i.uid, at: xy)
				continue
			}
			if u.type.isNaval, let center = navalCenters[u.country.team],
			   let xy = nearestPlacement(for: u, near: center) {
				place(i.uid, at: xy)
				continue
			}

			var k = allocatedUnits[player]
			while k < placements[player].count, !canDeploy(u, at: placements[player][k]) {
				k += 1
			}
			if k < placements[player].count {
				place(i.uid, at: placements[player][k])
				allocatedUnits[player] = k + 1
				continue
			}

			var fallback: XY?
			for xy in self.map.indices where canDeploy(u, at: xy) {
				fallback = xy
				break
			}
			guard let fallback else { fatalError() }
			place(i.uid, at: fallback)
		}

		refreshVision()
	}

	private func canDeploy(_ u: Unit, at xy: XY) -> Bool {
		guard map.contains(xy), unitsMap[xy] == .none else { return false }
		return u.type.isNaval
			? map[xy].isSea && !hasAdjacentShip(at: xy)
			: u.isAir ? !map[xy].isNoFlyZone : !map[xy].isSea && !map[xy].isRiver
	}

	private func nearestPlacement(for unit: Unit, near center: XY) -> XY? {
		var result: XY?
		var bestDistance = Int.max
		for xy in map.indices where canDeploy(unit, at: xy) {
			let distance = xy.manhattanDistance(to: center)
			if distance < bestDistance {
				result = xy
				bestDistance = distance
			}
		}
		return result
	}

	private func hasAdjacentShip(at xy: XY) -> Bool {
		xy.n4.contains { p in
			guard map.contains(p) else { return false }
			let uid = unitsMap[p]
			return uid != .none && units[uid].type.isNaval
		}
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

	internal mutating func refreshVision() {
		for i in players.indices {
			vision[i] = vision(for: players[i].country)
		}
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
