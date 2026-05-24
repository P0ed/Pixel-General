struct TacticalState: ~Copyable {
	var map: Map<Terrain>
	var players: CArray<4, Player>
	var auxilia: [4 of CArray<16, Unit>]
	var control: Map<Country>
	var units: Speicher<128, Unit>
	var position: [128 of XY]
	var cargo: [128 of UID]
	var unitsMap: Map<UID>
	var turn: UInt32 = 0
	var d20: D20 = D20()
	var events: CArray<128, TacticalEvent> = .init(tail: .end)

	var cursor: XY = .zero
	var camera: XY = .zero
	var selectedUnit: UID?
	var selectable: SetXY?
	var scale: Int = 1
}

extension TacticalState {

	init(map: consuming Map<Terrain>, players: [Player], cities: [(XY, Country)], units: [Unit]) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.units = .init(head: units, tail: .empty)
		self.position = .init(repeating: .zero)
		cargo = .init(repeating: -1)
		unitsMap = .init(size: self.map.size, zero: -1)
		control = .init(size: self.map.size, zero: .default)
		auxilia = .init { i in
			CArray(
				head: i < players.count ? .aux(country: players[i].country) : [],
				tail: .empty
			)
		}
		cities.forEach { xy, c in control[xy] = c }
		assignControl()

		let size = self.map.size
		let placements = [4 of CArray<1024, XY>].init { i in
			guard i < players.count else { return .init(tail: .zero) }

			let cityXYs = cities
				.filter { _, c in c == players[i].country }
				.map { xy, _ in xy }
			let disks = (cityXYs.isEmpty ? [.zero] : cityXYs).map { $0.circle(9) }
			var out = CArray<1024, XY>(tail: .zero)
			var cursors = [Int](repeating: 0, count: disks.count)
			var progressed = true
			while progressed {
				progressed = false
				for k in disks.indices where cursors[k] < disks[k].count {
					out.add(disks[k][cursors[k]])
					cursors[k] += 1
					progressed = true
				}
			}
			return out
		}
		var allocatedUnits = [0, 0, 0, 0] as [4 of Int]

		self.units.forEach { i, u in
			guard let player = players.firstIndex(where: { p in p.country == u.country })
			else { return }

			let candidates = placements[player]
			var k = allocatedUnits[player]
			while k < candidates.count {
				let xy = candidates[k]
				if xy.x >= 0, xy.y >= 0, xy.x < size, xy.y < size,
					unitsMap[xy] < 0, !self.map[xy].isRiver {
					break
				}
				k += 1
			}
			guard k < candidates.count else { fatalError() }

			position[i] = candidates[k]
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

	var visibleToHuman: SetXY {
		players.reduce(into: .empty) { r, _, p in
			p.type == .human ? r.combine(p.visible) : ()
		}
	}
}

extension TacticalState {

	mutating func assignControl() {
		var cityXYs: [XY] = []
		var cityOwners: [Country] = []
		for xy in map.indices where map[xy] == .city {
			cityXYs.append(xy)
			cityOwners.append(control[xy])
		}
		guard !cityXYs.isEmpty else { return }

		for xy in map.indices where map[xy] != .city {
			var best = 0
			var bestD = xy.manhattanDistance(to: cityXYs[0])
			for k in 1 ..< cityXYs.count {
				let d = xy.manhattanDistance(to: cityXYs[k])
				if d < bestD { bestD = d; best = k }
			}
			control[xy] = cityOwners[best]
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

	func isVisible(_ id: UID) -> Bool {
		unitsMap[position[id.index]] == id && player.visible[position[id.index]]
	}

	func isVisibleToHuman(_ id: UID) -> Bool {
		unitsMap[position[id.index]] == id && isVisibleToHuman(position[id.index])
	}

	func isVisibleToHuman(_ xy: XY) -> Bool {
		players.contains { p in p.type == .human && p.visible[xy] }
	}
}

extension Terrain {

	var income: UInt16 {
		switch self {
		case .city: 0xE
		case .villageE, .villageN, .villageS, .villageW: 0xA
		case .airfield: 0x6
		default: 0
		}
	}
}
