struct TacticalState: ~Copyable {
	var map: Map<Terrain>
	var players: Speicher<4, Player>
	var buildings: CArray<32, Building>
	var units: Speicher<128, Unit>
	var unitsMap: Map<UID>
	var cargo: [128 of Unit]
	var auxilia: [4 of CArray<16, Unit>]
	var events: CArray<4, TacticalEvent> = .init(tail: .none)
	var d20: D20 = D20()
	var turn: UInt32 = 0
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
		unitsMap = .init(size: self.map.size, zero: -1)
		cargo = .init(repeating: .empty)
		auxilia = .init { i in
			CArray(
				head: .aux(country: players[i].country),
				tail: .empty
			)
		}
		self.units.map { i, u in (i, u.position) }.forEach { i, xy in
			guard unitsMap[xy] < 0 else { fatalError() }
			unitsMap[xy] = i.uid
		}

		buildings.forEach { b in
			switch b.type {
			case .city: self.map[b.position] = .city
			case .airfield: self.map[b.position] = .airfield
			}
		}

		let v = Dictionary(uniqueKeysWithValues: self.players.map { i, p in
			(i, vision(for: p.country))
		})
		self.players.modifyEach { i, p in p.visible = v[i] ?? .empty }
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
}

extension Building {

	var income: UInt16 {
		switch type {
		case .city: 0x12
		case .airfield: 0x06
		}
	}
}
