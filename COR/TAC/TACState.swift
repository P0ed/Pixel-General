public struct TacticalSim: ~Copyable {
	public var map: Map<64, Terrain>
	public var control: Map<64, Country>
	public var unitsMap: Map<64, UID>
	public var settlements: SetXY = .empty

	public var players: CArray<4, Player>
	public var vision: [4 of SetXY]

	public var units: Speicher<192, Unit>
	public var position: [192 of XY]
	public var cargo: [192 of UID]

	public var turn: UInt32 = 0
	public var d20: D20 = D20()

	public var objective: Objective = .none
	public var isFinished = false
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
		deployStartingUnits(homes: homes)

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
			guard homes[u.country] == nil, let player = players.firstIndex(where: { p in p.country == u.country })
			else { continue }
			if u.isNaval, let center = navalCenters[u.country.team],
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

	private mutating func deployStartingUnits(homes: [Country: XY]) {
		guard !homes.isEmpty else { return }
		let footprints = map.cityFootprints
		for seat in players.indices {
			let country = players[seat].country
			guard let spawn = homes[country] else { continue }
			func closerToSpawn(_ a: XY, _ b: XY) -> Bool {
				(a.manhattanDistance(to: spawn), a.y, a.x) < (b.manhattanDistance(to: spawn), b.y, b.x)
			}
			var cities = footprints.compactMap { footprint -> [XY]? in
				let owned = footprint.filter { control[$0] == country }
				return owned.isEmpty ? nil : owned.sorted(by: closerToSpawn)
			}
			cities.sort { closerToSpawn($0[0], $1[0]) }
			let home = cities.first ?? [spawn]
			let otherCities = cities.count > 1 ? Array(cities.dropFirst()) : [home]
			let roster = units.indices.filter { units[$0].alive && units[$0].country == country }
			for i in roster where !units[i][.aux] {
				deploy(i, at: home)
			}
			let auxiliaries = roster.filter { units[$0][.aux] }
			for (offset, i) in auxiliaries.enumerated() {
				deploy(i, at: otherCities[offset % otherCities.count])
			}
		}
	}

	private mutating func deploy(_ index: Int, at city: [XY]) {
		let unit = units[index]
		let xy = city.first { canDeploy(unit, at: $0) } ?? nearestPlacement(for: unit, near: city[0])
		guard let xy else { fatalError() }
		place(index.uid, at: xy)
	}

	static var empty: TacticalSim {
		var state = TacticalSim(
			map: Map<64, Terrain>(seed: Int.random(in: 0 ..< Int.max)),
			players: [.none],
			cities: [],
			units: []
		)
		state.isFinished = true
		return state
	}

	private func canDeploy(_ u: Unit, at xy: XY) -> Bool {
		guard map.contains(xy), unitsMap[xy] == .none else { return false }
		return u.isNaval
			? map[xy].isSea
			: u.isAir || !map[xy].isSea && !map[xy].isRiver
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

	subscript(_ xy: XY) -> Unit? {
		get {
			unitAt(xy)
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
