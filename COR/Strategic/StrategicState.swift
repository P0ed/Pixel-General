/// Deterministic strategic simulation state — province ownership, the turn
/// counter, and the reducer. Owns everything `reduce` may touch.
public struct StrategicSim: ~Copyable {
	public var owner: Map<32, Country>
	public var terrain: Map<32, Terrain>
	public var provinces: Map<32, Province>
	public var player: Player
	/// Four army slots for each possible `Country.rawValue`.
	public var armies: CArray<64, CArray<4, Army>>
	public var turn: UInt32
	public var battle: XY?
	public var battleArmy: UInt8

	public init(
		owner: consuming Map<32, Country>,
		terrain: consuming Map<32, Terrain> = Map(size: 32, zero: .field),
		provinces: consuming Map<32, Province> = Map(size: 32, zero: Province()),
		player: Player,
		armies: consuming CArray<64, CArray<4, Army>> = StrategicSim.emptyArmies(),
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

	public static func emptyArmies() -> CArray<64, CArray<4, Army>> {
		let countries: [64 of CArray<4, Army>] = .init { _ in
			CArray([4 of Army].init(repeating: Army()))
		}
		return CArray(countries)
	}

	/// In-place campaign construction keeps the 64×4 inline army store out of
	/// factory-function temporary return buffers (notably Swift Testing's small
	/// worker stacks).
	public init(europe player: Player) {
		owner = Map<32, Country>(size: 32, zero: .none)
		terrain = Map<32, Terrain>(size: 32, zero: .field)
		provinces = Map<32, Province>(size: 32, zero: Province())
		self.player = player
		armies = CArray([64 of CArray<4, Army>].init { _ in
			CArray([4 of Army].init(repeating: Army()))
		})
		turn = 0
		battle = nil
		battleArmy = 0

		let rows = mapASCII.split(separator: "\n", omittingEmptySubsequences: false)
		for (row, line) in rows.enumerated() {
			// Flip the row so north (top of the ASCII) maps to higher `y`.
			let y = 31 - row
			for (x, ch) in line.enumerated() where x < 32 {
				if let country = Country(legend: ch) { owner[XY(x, y)] = country }
			}
		}
		let terrainRows = terrainASCII.split(separator: "\n", omittingEmptySubsequences: false)
		for (row, line) in terrainRows.enumerated() {
			let y = 31 - row
			for (x, ch) in line.enumerated() where x < 32 {
				if let tile = Terrain(legend: ch) { terrain[XY(x, y)] = tile }
			}
		}
		placeStartingFactories()
		foundStartingArmies()
	}
}

public extension StrategicSim {

	static var captureRadius: Int { 2 }

	// Field reads for callers holding `StrategicSim?` — projecting stored
	// fields out of the noncopyable sim through optional chains hangs the
	// compiler, so outside access goes through methods.
	func owner(at xy: XY) -> Country { owner[xy] }
	func terrain(at xy: XY) -> Terrain { terrain[xy] }
	func fortLevel(at xy: XY) -> Int { Int(provinces[xy][.fort]) }

	func canAttack(_ xy: XY) -> Bool {
		canAttack(xy, by: player.country)
	}

	func canAttack(_ xy: XY, by country: Country) -> Bool {
		guard owner.contains(xy) else { return false }
		let target = owner[xy]
		guard target != .none, target.team != country.team else { return false }
		return attackingArmy(at: xy, for: country) != nil
	}

	func canAttack(_ xy: XY, with army: ArmyID) -> Bool {
		guard owner.contains(xy),
			owner[xy] != .none,
			owner[xy].team != army.country.team,
			armyIsActive(army.index, for: army.country),
			hasCoreForce(army.index, for: army.country)
		else { return false }
		let fieldArmy = self.army(army)
		guard fieldArmy.mp > 0 else { return false }
		let n4 = fieldArmy.position.n4
		for index in 0 ..< n4.count where n4[index] == xy { return true }
		return false
	}

	func attackingArmy(at xy: XY) -> Int? {
		attackingArmy(at: xy, for: player.country)
	}

	func attackingArmy(at xy: XY, for country: Country) -> Int? {
		let countryIndex = Int(country.rawValue)
		for slot in 0 ..< 4 {
			let army = armies[countryIndex][slot]
			guard army.active, army.mp > 0, hasCoreForce(slot, for: country) else { continue }
			let n4 = army.position.n4
			for k in 0 ..< n4.count where n4[k] == xy {
				return slot
			}
		}
		return nil
	}

	mutating func resolveBattle(at tile: XY, won: Bool, by country: Country) {
		battle = nil
		let slot = Int(battleArmy)
		battleArmy = 0
		guard won else { return }
		capture(at: tile, by: ArmyID(country: country, slot: slot))
	}

	/// Deterministically resolves a strategic battle without entering Tactical.
	/// The stronger local force wins; AI callers separately require a 3:1 edge.
	@discardableResult
	mutating func autoResolveAttack(at tile: XY, by army: ArmyID) -> Bool? {
		guard canAttack(tile, with: army) else { return nil }

		let defender = owner[tile]
		let attack = localStrength(of: army.country, near: tile)
		let defence = localStrength(of: defender, near: tile)
		armies[Int(army.country.rawValue)][army.index].mp = 0
		let won = attack >= max(1, defence)
		if won { capture(at: tile, by: army) }
		return won
	}

	func hasLocalAdvantage(_ army: ArmyID, attacking tile: XY, ratio: Int = 3) -> Bool {
		guard owner.contains(tile), owner[tile] != .none else { return false }
		let attack = localStrength(of: army.country, near: tile)
		let defence = localStrength(of: owner[tile], near: tile)
		return attack >= max(1, defence) * ratio
	}

	func localStrength(of country: Country, near tile: XY) -> Int {
		let countryIndex = Int(country.rawValue)
		var strength = 0
		for slot in 0 ..< 4 {
			let army = armies[countryIndex][slot]
			guard army.active,
				max(abs(army.position.x - tile.x), abs(army.position.y - tile.y)) <= Army.defRange
			else { continue }
			strength += army.strength
		}
		return strength
	}

	private mutating func capture(at tile: XY, by army: ArmyID) {
		guard owner.contains(tile), owner[tile] != .none else { return }
		let country = army.country
		let countryIndex = Int(country.rawValue)
		if armies[countryIndex][army.index].active {
			armies[countryIndex][army.index].position = tile
		}
		let defeatedTeam = owner[tile].team
		let r = Self.captureRadius
		for xy in owner.indices where owner[xy] != .none
			&& owner[xy].team == defeatedTeam
			&& abs(xy.x - tile.x) <= r
			&& abs(xy.y - tile.y) <= r
		{
			owner[xy] = country
		}
		retreatDisplacedArmies(except: army)
	}

	/// Captures may engulf nearby army tiles. Move each displaced force to the
	/// nearest province its country still owns, or disband it if none remains.
	private mutating func retreatDisplacedArmies(except winner: ArmyID) {
		for country in Country.playable where country != winner.country {
			let countryIndex = Int(country.rawValue)
			for slot in 0 ..< 4 {
				let fieldArmy = armies[countryIndex][slot]
				guard fieldArmy.active, owner[fieldArmy.position] != country else { continue }
				var best: XY?
				var distance = Int.max
				for xy in owner.indices where owner[xy] == country && army(at: xy) == nil {
					let d = fieldArmy.position.stepDistance(to: xy)
					if d < distance { best = xy; distance = d }
				}
				if let best {
					armies[countryIndex][slot].position = best
					armies[countryIndex][slot].mp = 0
				} else {
					armies[countryIndex][slot].active = false
				}
			}
		}
	}
}

public extension StrategicSim {

	/// Build the European campaign map from the docs/Map.md legend and place
	/// the starting factories — deterministic, identical output every call.
	static func europe(player: Player) -> StrategicSim {
		StrategicSim(europe: player)
	}

	mutating func foundStartingArmies() {
		for country in Country.playable {
			foundMainArmy(for: country)
			guard country != player.country, armyIsActive(0, for: country) else { continue }
			var base = [Unit].base(country)
			base.modifyEach { unit in unit.reset() }
			setRoster(
				[16 of Unit](head: Array(base.prefix(16)), tail: .empty),
				slot: 0,
				for: country
			)
		}
	}

	mutating func foundMainArmy() {
		foundMainArmy(for: player.country)
	}

	mutating func foundMainArmy(for country: Country) {
		let center = centroid(for: country)
		var best: XY?
		var bestDistance = Int.max
		for xy in owner.indices where owner[xy] == country {
			let d = xy.stepDistance(to: center)
			if d < bestDistance {
				best = xy
				bestDistance = d
			}
		}
		guard let best else { return }
		armies[Int(country.rawValue)][0] = modifying(Army()) { a in
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

	/// Maps a terrain-overlay legend character to a strategic terrain.
	init?(legend ch: Character) {
		switch ch {
		case "^": self = .mountain
		case "n": self = .hill
		case "f": self = .forest
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

/// Terrain overlay for `mapASCII` (same 32×32 grid): `^` mountain, `n` hill,
/// `f` forest, `.` field. Rough real-world ranges — the northern European
/// forests; Scandinavian spine, Kola and Lapland fells; Valdai and Central
/// Russian uplands; German uplands; Sudetes/Ore Mountains; the Alps; and the
/// Carpathian arc.
private let terrainASCII = """
................................
................................
.............n^^nffff...........
...........f^^nffnfffnnff.ff....
..........^^nfffffnfffnf.fff...f
.........^^nfffffffffff...f.....
........^^nffff...ffff.ff....f.f
.......^^nfffff..ffffffff..ff.ff
.....n^^nfffff..ffffffff.fff.fff
...fn^^^nfff...ffffffff.fnn.fff.
..fn^^^nffff...fffffff.fnnnfff.f
..ff^^^nffff....fffff.fffnfff.ff
..ffnnnffffff........fff.fff.fff
...nn..ffffff...fffffff.fff.fff.
.......fnnff.....fffff.fff.fff.f
........fff....ffffff.fff.fff.ff
........f......ffffff.ff.fff.fff
................fff...f..f..f..f
............f...f...f...f..f..f.
..........f...f...f...ff..f..f..
............f...f...f.......f..f
..........f...f............nn.f.
.....n.nn...f...f..........nn...
....nnn^nn....f.................
....n...n...n^^nnn..............
.....nn^^^nnn...^^nn............
....^^^^^nn....n^^n.............
........nnn....^^^n.............
...............nn...............
................................
................................
................................
"""
