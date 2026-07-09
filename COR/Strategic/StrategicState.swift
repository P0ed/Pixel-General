/// Deterministic strategic simulation state — province ownership, the turn
/// counter, and the reducer. Owns everything `reduce` may touch.
public struct StrategicSim: ~Copyable {
	/// Per-tile province ownership — the political map (see docs/Map.md).
	public var owner: Map<32, Country>
	/// Per-tile dominant terrain (`.field`/`.hill`/`.mountain`) — drawn as
	/// elevation on the political map and passed to tactical map generation.
	public var terrain: Map<32, Terrain>
	/// The country the player commands this campaign.
	public var human: Country
	public var turn: UInt32
	/// The contested tile while a campaign battle is running; `nil` otherwise.
	/// Set when an offensive launches, read on battle completion to flip control.
	public var battle: XY?

	public init(
		owner: consuming Map<32, Country>,
		terrain: consuming Map<32, Terrain> = Map(size: 32, zero: .field),
		human: Country = .default,
		turn: UInt32 = 0,
		battle: XY? = nil
	) {
		self.owner = owner
		self.terrain = terrain
		self.human = human
		self.turn = turn
		self.battle = battle
	}
}

@frozen public enum StrategicMapMode: UInt8, Hashable {
	case team, country
}

/// Presentation-only strategic state. Never read by `reduce`; may diverge per peer.
public struct StrategicUI {
	public var cursor: XY
	public var camera: XY
	public var scale: Int
	public var mapMode: StrategicMapMode

	public init(
		cursor: XY = .zero,
		camera: XY = .zero,
		scale: Int = 2,
		mapMode: StrategicMapMode = .team
	) {
		self.cursor = cursor
		self.camera = camera
		self.scale = scale
		self.mapMode = mapMode
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

	/// Tiles within this Chebyshev radius of the attacked tile flip on a win.
	static var captureRadius: Int { 2 }

	/// A tile is attackable when it belongs to an enemy team and borders a tile
	/// the player owns. Sea tiles are never attackable.
	func canAttack(_ xy: XY) -> Bool {
		guard owner.contains(xy) else { return false }
		let target = owner[xy]
		guard target != .none, target.team != human.team else { return false }
		return xy.n8.firstMap { n in owner.contains(n) && owner[n] == human ? n : nil } != nil
	}

	/// Apply a finished campaign battle: on a win, flip ownership of land tiles
	/// within `captureRadius` of the attacked tile to the victor.
	mutating func resolveBattle(at tile: XY, won: Bool, by country: Country) {
		battle = nil
		guard won else { return }
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

	/// Build the European campaign map from the docs/Map.md legend.
	static func europe(human: Country) -> StrategicSim {
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
		return StrategicSim(owner: owner, terrain: terrain, human: human)
	}

	/// The average tile position of every province owned by `country` — used
	/// to centre the initial camera/cursor. Accumulates in `Int` (`XY` is
	/// backed by `Int8` and would overflow summing many tiles); falls back to
	/// the map's centre when `country` owns nothing.
	func centroid(for country: Country) -> XY {
		var sx = 0, sy = 0, count = 0
		for xy in owner.indices where owner[xy] == country {
			sx += xy.x
			sy += xy.y
			count += 1
		}
		guard count > 0 else { return XY(owner.size / 2, owner.size / 2) }
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
....nn.nn..................nn...
....nnn^nn......................
....nnn.n...n^^nnn..............
.....nn^^^nnn...^^nn............
....^^^^^nn....n^^n.............
........nnn....^^^n.............
...............nn...............
................................
................................
................................
"""
