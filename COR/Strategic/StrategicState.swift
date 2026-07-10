/// Deterministic strategic simulation state — province ownership, the turn
/// counter, and the reducer. Owns everything `reduce` may touch.
public struct StrategicSim: ~Copyable {
	public var owner: Map<32, Country>
	public var terrain: Map<32, Terrain>
	public var provinces: Map<32, Province>
	public var player: Player
	public var armies: [4 of Army]
	public var turn: UInt32
	public var battle: XY?
	public var battleArmy: UInt8

	public init(
		owner: consuming Map<32, Country>,
		terrain: consuming Map<32, Terrain> = Map(size: 32, zero: .field),
		provinces: consuming Map<32, Province> = Map(size: 32, zero: Province()),
		player: Player,
		armies: [4 of Army] = .init(repeating: Army()),
		turn: UInt32 = 0,
		battle: XY? = nil,
		battleArmy: UInt8 = 0
	) {
		self.owner = owner
		self.terrain = terrain
		self.provinces = provinces
		self.player = player
		self.armies = armies
		self.turn = turn
		self.battle = battle
		self.battleArmy = battleArmy
	}
}

@frozen public enum StrategicMapMode: UInt8, Hashable {
	case country, team
}

/// Presentation-only strategic state. Never read by `reduce`; may diverge per peer.
public struct StrategicUI {
	public var cursor: XY
	public var camera: XY
	public var scale: Int
	public var mapMode: StrategicMapMode
	/// The army slot picked for a move order, with its move range.
	public var selected: Int?
	public var selectable: SetXY?

	public init(
		cursor: XY = .zero,
		camera: XY = .zero,
		scale: Int = 1,
		mapMode: StrategicMapMode = .country,
		selected: Int? = nil,
		selectable: SetXY? = nil
	) {
		self.cursor = cursor
		self.camera = camera
		self.scale = scale
		self.mapMode = mapMode
		self.selected = selected
		self.selectable = selectable
	}
}

public struct StrategicState: ~Copyable {
	public var sim: StrategicSim
	public var ui: StrategicUI

	public init(sim: consuming StrategicSim, ui: StrategicUI = StrategicUI()) {
		self.sim = sim
		self.ui = ui
	}
}

public extension StrategicSim {

	static var captureRadius: Int { 2 }

	func canAttack(_ xy: XY) -> Bool {
		guard owner.contains(xy) else { return false }
		let target = owner[xy]
		guard target != .none, target.team != player.country.team else { return false }
		return attackingArmy(at: xy) != nil
	}

	func attackingArmy(at xy: XY) -> Int? {
		let armies = armies
		for i in 0 ..< 4 where armies[i].active && armies[i].mp > 0 && hasCoreForce(i) {
			let n4 = armies[i].position.n4
			for k in 0 ..< n4.count where n4[k] == xy {
				return i
			}
		}
		return nil
	}

	mutating func resolveBattle(at tile: XY, won: Bool, by country: Country) {
		battle = nil
		let slot = Int(battleArmy)
		battleArmy = 0
		guard won else { return }
		if armies[slot].active {
			armies[slot].position = tile
		}
		let r = Self.captureRadius
		for xy in owner.indices where owner[xy] != .none
			&& owner[xy].team == owner[tile].team
			&& abs(xy.x - tile.x) <= r
			&& abs(xy.y - tile.y) <= r
		{
			owner[xy] = country
		}
	}
}

public extension StrategicSim {

	/// Build the European campaign map from the docs/Map.md legend and place
	/// the starting factories — deterministic, identical output every call.
	static func europe(player: Player) -> StrategicSim {
		var owner = Map<32, Country>(size: 32, zero: .none)
		let rows = mapASCII.split(separator: "\n", omittingEmptySubsequences: false)
		for (row, line) in rows.enumerated() {
			// Flip the row so north (top of the ASCII) maps to higher `y`.
			let y = 31 - row
			for (x, ch) in line.enumerated() where x < 32 {
				if let c = Country(legend: ch) { owner[XY(x, y)] = c }
			}
		}
		var terrain = Map<32, Terrain>(size: 32, zero: .field)
		let terrainRows = terrainASCII.split(separator: "\n", omittingEmptySubsequences: false)
		for (row, line) in terrainRows.enumerated() {
			let y = 31 - row
			for (x, ch) in line.enumerated() where x < 32 {
				if let t = Terrain(legend: ch) { terrain[XY(x, y)] = t }
			}
		}
		var sim = StrategicSim(owner: owner, terrain: terrain, player: player)
		sim.placeStartingFactories()
		sim.foundMainArmy()
		return sim
	}

	mutating func foundMainArmy() {
		let center = centroid(for: player.country)
		var best: XY?
		var bestDistance = Int.max
		for xy in owner.indices where owner[xy] == player.country {
			let d = xy.stepDistance(to: center)
			if d < bestDistance {
				best = xy
				bestDistance = d
			}
		}
		guard let best else { return }
		armies[0] = modifying(Army()) { a in
			a.position = best
			a.mp = Army.moveSpeed
			a.active = true
		}
	}

	func centroid(for country: Country) -> XY {
		var sx = 0, sy = 0, count = 0
		for xy in owner.indices where owner[xy] == country {
			sx += xy.x
			sy += xy.y
			count += 1
		}
		guard count > 0 else { return .zero }
		return XY(sx / count, sy / count)
	}
}

extension Terrain {

	/// Maps a docs/Map.md elevation legend character to a strategic terrain.
	init?(legend ch: Character) {
		switch ch {
		case "^": self = .mountain
		case "n": self = .hill
		case ".": self = .field
		default: return nil
		}
	}
}

extension Country {

	/// Maps a docs/Map.md legend character to a country.
	init?(legend ch: Character) {
		switch ch {
		case "S": self = .swe
		case "D": self = .den
		case "W": self = .nor
		case "F": self = .fin
		case "G": self = .ger
		case "N": self = .ned
		case "E": self = .est
		case "V": self = .lva
		case "L": self = .ltu
		case "P": self = .pol
		case "B": self = .bel
		case "C": self = .cze
		case "K": self = .svk
		case "O": self = .aut
		case "R": self = .rom
		case "H": self = .hun
		case "U": self = .ukr
		case "M": self = .mol
		case "Z": self = .rus
		case ".": self = .none
		default: return nil
		}
	}
}

private let mapASCII = """
................................
................................
.............WWWWWWWW...........
...........WWWSFFFFFZZZZZZZZ....
..........WWSSSSSFFFFZZZZZZZZ..Z
.........WWSSSSSSFFFFZZZ..ZZ...Z
........WWSSSSS...FFFZZZZ....ZZZ
.......WWSSSSSS..FFFFFZZZZ.ZZZZZ
.....WWWSSSSSS..FFFFFFZZZZZZZZZZ
...WWWWWSSSS...FFFFFFFFZZZZZZZZZ
..WWWWWWSSSS...FFFFFFFZZZZZZZZZZ
..WWWWWWSSSS....FFFFFZZZZZZZZZZZ
..WWWWWSSSSSS........ZZZZZZZZZZZ
...WW..SSSSSS...EEEEZZZZZZZZZZZZ
.......SSSSS.....VVEZZZZZZZZZZZZ
....DD..SSS....VVVVVZZZZZZZZZZZZ
....DDD.S......LLLLVBBZZZZZZZZZZ
....DD.....PP.ZZLLLBBBBZZZZZZZZZ
....GGGG.PPPPPPPPBBBBBBBZZZZZZZZ
.NNGGGGGGPPPPPPPPBBBBBBZZZZZZZZZ
NNGGGGGGGPPPPPPPPBBBBBBBUUZZZZZZ
NNGGGGGGGPPPPPPPPUUUUUUUUUZZZZZZ
..GGGGGCCCPPPPPPPUUUUUUUUUUUUZZZ
..GGGGGCCCCCCPPPUUUUUUUUUUUUUUUZ
...GGGGGCCCCKKKKUUUUUUUUUUUUUUUZ
...GGGGOOOOKKKHHUUURMMUUUUUUUUZZ
....OOOOOOOHHHHRRRRRRMUUUUUU..ZZ
........OOOHHHHRRRRRRUU...U...ZZ
...............RRRRRRR...UUU..ZZ
.................RRRR..........Z
................................
................................
"""

/// Elevation overlay for `mapASCII` (same 32×32 grid): `^` mountain, `n` hill,
/// `.` field. Rough real-world ranges — the Scandinavian spine, Kola and
/// Lapland fells, Valdai and Central Russian uplands, the German uplands,
/// Sudetes/Ore Mountains, the Alps, and the Carpathian arc.
private let terrainASCII = """
................................
................................
.............n^^n...............
............^^n..n...nn.........
..........^^n.....n...n.........
.........^^n....................
........^^n.....................
.......^^n......................
.....n^^n.......................
....n^^^n................nn.....
...n^^^n................nnn.....
....^^^n.................n......
....nnn.........................
...nn...........................
........nn......................
................................
................................
................................
................................
................................
................................
...........................nn...
.....n.nn..................nn...
....nnn^nn......................
....n...n...n^^nnn..............
.....nn^^^nnn...^^nn............
....^^^^^nn....n^^n.............
........nnn....^^^n.............
...............nn...............
................................
................................
................................
"""
