struct TacticalState: ~Copyable {
	var map: Map<32, Terrain>
	var control: Map<32, Country>
	var unitsMap: Map<32, UID>

	var players: CArray<4, Player>
	var auxilia: [4 of CArray<16, Unit>]

	var units: Speicher<128, Unit>
	var position: [128 of XY]
	var cargo: [128 of UID]

	var turn: UInt32 = 0
	var d20: D20 = D20()
	var events: CArray<128, TacticalEvent> = .init(tail: .end)

	var cursor: XY = .zero
	var camera: XY = .zero
	var selectedUnit: UID = .none
	var selectable: SetXY?
	var scale: Int = 1
	var mapMode: MapMode = .terrain
}

enum MapMode: UInt8, Hashable {
	case terrain, political
}

extension TacticalState {

	init(map: consuming Map<32, Terrain>, players: [Player], cities: [(XY, Country)], units: [Unit]) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.units = .init(head: units, tail: .empty)
		self.position = .init(repeating: .zero)
		cargo = .init(repeating: .none)
		unitsMap = .init(size: self.map.size, zero: .none)
		control = .init(size: self.map.size, zero: .default)
		auxilia = .init { i in
			CArray(
				head: i < players.count ? .aux(country: players[i].country) : [],
				tail: .empty
			)
		}
		cities.forEach { xy, c in control[xy] = c }
		for xy in self.map.indices where self.map[xy].isVillage || self.map[xy] == .airfield {
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

		self.units.forEachAlive { i, u in
			guard let player = players.firstIndex(where: { p in p.country == u.country })
			else { return }

			var k = allocatedUnits[player]
			while k < placements[player].count {
				let xy = placements[player][k]
				if self.map.contains(xy), unitsMap[xy] == .none, !self.map[xy].isRiver {
					break
				}
				k += 1
			}
			guard k < placements[player].count else { fatalError() }

			position[i] = placements[player][k]
			allocatedUnits[player] = k + 1
			unitsMap[position[i]] = i.uid
		}

		let v = self.players.map { i, p in vision(for: p.country) }
		self.players.modifyEach { i, p in p.visible = v[i] }
	}

	subscript(_ xy: XY) -> Unit? {
		get {
			let idx = unitsMap[xy].index
			return if idx < 0 { nil } else { units[idx] }
		}
		set {
			let idx = unitsMap[xy].index
			if idx >= 0 { units[idx] = newValue ?? .empty }
		}
	}

	subscript(_ country: Country) -> Player {
		get {
			players.firstMap { _, p in p.country == country ? p : nil } ?? Player()
		}
		set {
			if let idx = players.firstMap({ i, p in p.country == country ? i : nil }) {
				players[idx] = newValue
			}
		}
	}
}

extension TacticalState {

	mutating func assignControl() {
		var anchors: [XY] = []
		var owners: [Country] = []
		for xy in map.indices where map[xy].isSettlement {
			anchors.append(xy)
			owners.append(control[xy])
		}
		guard !anchors.isEmpty else { return }

		for xy in map.indices where !map[xy].isSettlement {
			var best = 0
			var bestD = xy.manhattanDistance(to: anchors[0])
			for k in 1 ..< anchors.count {
				let d = xy.manhattanDistance(to: anchors[k])
				if d < bestD { bestD = d; best = k }
			}
			control[xy] = owners[best]
		}
	}
}

extension TacticalState {

	var playerIndex: Int { Int(turn) % players.count }

	var player: Player {
		get { players[playerIndex] }
		set { players[playerIndex] = newValue }
	}

	var country: Country { player.country }

	func offMap(unit id: UID) -> Bool {
		unitsMap[position[id]] != id
	}

	func isVisible(_ id: UID) -> Bool {
		!offMap(unit: id) && player.visible[position[id]]
	}

	func isVisibleToHuman(_ id: UID) -> Bool {
		!offMap(unit: id) && isVisibleToHuman(position[id])
	}

	func isVisibleToHuman(_ xy: XY) -> Bool {
		players.contains { p in p.type == .human && p.visible[xy] }
	}

	var visibleToHuman: SetXY {
		players.reduce(into: .empty) { r, _, p in
			p.type == .human ? r.combine(p.visible) : ()
		}
	}
}

extension Terrain {

	var income: UInt16 {
		switch self {
		case .city: 0xF
		case .villageE, .villageN, .villageS, .villageW: 0x7
		case .airfield: 0x3
		default: 0
		}
	}
}
