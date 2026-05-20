struct TacticalState: ~Copyable {
	var map: Map<Terrain>
	var players: CArray<4, Player>
	var auxilia: [4 of CArray<16, Unit>]
	var buildings: CArray<32, Building>
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

	init(map: consuming Map<Terrain>, players: [Player], buildings: [Building], units: [Unit]) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.buildings = .init(head: buildings, tail: .empty)
		self.units = .init(head: units, tail: .empty)
		self.position = .init(repeating: .zero)
		cargo = .init(repeating: -1)
		unitsMap = .init(size: self.map.size, zero: -1)
		auxilia = .init { i in
			CArray(
				head: i < players.count ? .aux(country: players[i].country) : [],
				tail: .empty
			)
		}
		let size = self.map.size
		let placements = [4 of CArray<1024, XY>].init { i in
			guard i < players.count else { return .init(tail: .zero) }

			let cities = buildings
				.filter {
					i < players.count && $0.country == players[i].country && $0.type == .city
				}
				.map { $0.position }
			let disks = (cities.isEmpty ? [.zero] : cities).map { $0.circle(9) }
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

		buildings.forEach { b in
			switch b.type {
			case .city: self.map[b.position] = .city
			case .airfield: self.map[b.position] = .airfield
			}
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

struct Building: Hashable {
	var country: Country
	var position: XY
	var type: BuildingType
}

enum BuildingType: UInt8, Hashable {
	case city, airfield
}

extension Building {

	static var empty: Building {
		Building(country: .default, position: .zero, type: .city)
	}
}

extension CArray where Element == Building {

	subscript(_ xy: XY) -> Building? {
		firstMap { _, b in b.position == xy ? b : nil }
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

extension Building {

	var income: UInt16 {
		switch type {
		case .city: 0x12
		case .airfield: 0x06
		}
	}
}
