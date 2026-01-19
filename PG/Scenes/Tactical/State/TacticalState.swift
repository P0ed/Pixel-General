struct TacticalState: ~Copyable {
	var map: Map<Terrain>
	var players: Speicher<4, Player>
	var buildings: Speicher<32, Building>
	var units: Speicher<128, Unit>
	var unitsMap: Map<UID>
	var events: Speicher<4, TacticalEvent> = .init(head: [], tail: .none)
	var seed: Crystals = .empty
	var turn: UInt32 = 0
	var cursor: XY = .zero
	var camera: XY = .zero
	var selectedUnit: UID?
	var selectable: SetXY?
	var scale: Double = 1.0
}

extension TacticalState {

	init(map: consuming Map<Terrain>, players: [Player], buildings: [Building], units: [Unit]) {
		self.map = map
		self.players = .init(head: players, tail: .none)
		self.buildings = .init(
			head: buildings,
			tail: .init(country: .ind, position: .zero, type: .city)
		)
		self.units = .init(head: units, tail: .none)
		unitsMap = .init(size: self.map.size, zero: -1)
		self.units.map { i, u in (i, u.position) }.forEach { i, xy in
			guard unitsMap[xy] < 0 else { fatalError() }
			unitsMap[xy] = i
		}

		buildings.forEach { b in
			switch b.type {
			case .city: self.map[b.position] = .city
			}
		}

		let v = Dictionary(uniqueKeysWithValues: self.players.map { i, p in
			(i, vision(for: p.country))
		})
		self.players.modifyEach { i, p in p.visible = v[i] ?? .empty }
	}

	subscript(_ xy: XY) -> Unit? {
		get {
			let idx = unitsMap[xy]
			return if idx < 0 { nil } else { units[idx] }
		}
		set {
			let idx = unitsMap[xy]
			if idx >= 0 { units[idx] = newValue ?? .none }
		}
	}

	var d20: D20 {
		get {
			D20(seed: UInt64(seed.rawValue) | UInt64(player.crystals.rawValue) << 8)
		}
		set {
			seed = Crystals(rawValue: UInt8(newValue.seed & 0xFF))
		}
	}
}

struct Building: Hashable, DeadOrAlive {
	var country: Country
	var position: XY
	var type: BuildingType
}

enum BuildingType: UInt8, Hashable {
	case city
}

enum TacticalEvent: Hashable {
	case spawn(UID)
	case move(UID, Int)
	case attack(UID, UID, UInt8, UInt8)
	case nextDay
	case shop
	case menu
	case gameOver
	case none
}

extension TacticalEvent: DeadOrAlive {

	var alive: Bool { self != .none }
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
		case .city: 0x10
		}
	}
}
