/// Fixed-size tensor view of the simulation from the acting player's
/// perspective — the single encoding shared by the trainer (`Train`) and the
/// in-app policy (`LSTMPolicy`), so the two can never drift apart.
///
/// Fog-correct by construction: an enemy unit exists in the tensor only while
/// `isVisible` holds for the acting player, and embarked cargo appears only as
/// its transport's `hasCargo` flag — exactly the information a human at the
/// screen has.
public struct SimObservation {
	public static let side = 32
	public static let planeCount = 53
	public static let globalCount = 12
	public static let planeSize = side * side

	/// HWC layout: `planes[(y * 32 + x) * planeCount + plane]`, all values 0…1.
	public var planes: [Float]
	public var globals: [Float]
}

/// Plane indices — the tensor contract. Append-only: reordering or repurposing
/// an index invalidates every trained weight file.
public enum Plane {
	public static let onMap = 0

	// Terrain, one-hot by mechanic group.
	public static let river = 1
	public static let bridge = 2
	public static let field = 3
	public static let forest = 4
	public static let hill = 5
	public static let forestHill = 6
	public static let mountain = 7
	public static let city = 8
	public static let airfield = 9
	public static let village = 10
	public static let road = 11

	public static let entrench = 12		// baseEntrenchment / 3
	public static let income = 13		// income / 24

	public static let controlOwn = 14	// control == acting country
	public static let controlTeam = 15	// control.team == acting team
	public static let controlEnemy = 16

	public static let unitFriendly = 17	// own-team unit on tile
	public static let unitEnemy = 18	// visible enemy-team unit on tile

	// Unit scalars (drawn for any unit present on the tile).
	public static let hp = 19
	public static let ammo = 20
	public static let ent = 21
	public static let mp = 22
	public static let ap = 23
	public static let lvl = 24

	public static let type0 = 25		// 14 `UnitType` one-hot planes: 25…38

	public static let transport = 39
	public static let hasCargo = 40
	public static let transportable = 41

	// Model stats, normalized — generalizes across the `UnitStats` table.
	public static let softAtk = 42
	public static let hardAtk = 43
	public static let airAtk = 44
	public static let groundDef = 45
	public static let airDef = 46
	public static let mov = 47
	public static let rng = 48
	public static let ini = 49

	public static let visible = 50		// acting player's fog of war

	// Appended terrain groups (previously folded into city / river).
	public static let fort = 51
	public static let sea = 52
}

/// Global scalar indices, same append-only contract as `Plane`.
public enum Global {
	public static let prestige = 0		// / 4096, clamped
	public static let day = 1			// / 128
	public static let tier = 2			// / 5
	public static let baseLevel = 3		// / 8
	public static let ownUnits = 4		// / 32
	public static let enemyUnits = 5	// visible, / 32
	public static let ownSettlements = 6	// team-held, / 32
	public static let enemySettlements = 7	// / 32
	public static let mustSurvive = 8	// objective is `.survive(myTeam, _)`
	public static let mustAnnihilate = 9	// objective is `.survive(enemy, _)`
	public static let deadline = 10		// remaining days / 128
	public static let mapSize = 11		// / 32
}

public extension TacticalSim {

	/// Encodes the state as seen by the acting player (`playerIndex`).
	func observation() -> SimObservation {
		var planes = [Float](repeating: 0, count: SimObservation.planeSize * SimObservation.planeCount)
		var globals = [Float](repeating: 0, count: SimObservation.globalCount)

		let me = player
		let myTeam = me.country.team
		let visible = vision[playerIndex]

		func put(_ xy: XY, _ plane: Int, _ value: Float) {
			planes[(xy.y * SimObservation.side + xy.x) * SimObservation.planeCount + plane] = value
		}

		var ownSettlements = 0
		var enemySettlements = 0
		for xy in map.indices {
			let t = map[xy]
			put(xy, Plane.onMap, 1)
			if let plane = t.plane { put(xy, plane, 1) }
			put(xy, Plane.entrench, Float(t.baseEntrenchment) / 3)
			put(xy, Plane.income, Float(t.income) / 24)

			let c = control[xy]
			if c == me.country { put(xy, Plane.controlOwn, 1) }
			if c.team == myTeam {
				put(xy, Plane.controlTeam, 1)
			} else {
				put(xy, Plane.controlEnemy, 1)
			}
			if visible[xy] { put(xy, Plane.visible, 1) }
			if t.isSettlement {
				if c.team == myTeam { ownSettlements += 1 } else { enemySettlements += 1 }
			}
		}

		var ownUnits = 0
		var enemyUnits = 0
		units.forEachAlive { i, u in
			guard !offMap(unit: i.uid) else { return }		// embarked cargo: transport's flag only
			let xy = position[i]
			let friendly = u.country.team == myTeam
			if friendly {
				ownUnits += 1
				put(xy, Plane.unitFriendly, 1)
			} else {
				guard visible[xy] else { return }			// fog: invisible enemies don't exist
				enemyUnits += 1
				put(xy, Plane.unitEnemy, 1)
			}

			put(xy, Plane.hp, Float(u.hp) / 15)
			put(xy, Plane.ammo, u.maxAmmo > 0 ? Float(u.ammo) / Float(u.maxAmmo) : 0)
			put(xy, Plane.ent, min(1, Float(u.ent) / 24))
			put(xy, Plane.mp, Float(u.mp) / Float(u.maxMP))
			put(xy, Plane.ap, Float(u.ap))
			put(xy, Plane.lvl, Float(u.lvl) / 8)
			put(xy, Plane.type0 + Int(u.type.rawValue), 1)

			if u[.transport] { put(xy, Plane.transport, 1) }
			if cargo[i] != .none { put(xy, Plane.hasCargo, 1) }
			if u.transportable { put(xy, Plane.transportable, 1) }

			put(xy, Plane.softAtk, min(1, Float(u.softAtk) / 20))
			put(xy, Plane.hardAtk, min(1, Float(u.hardAtk) / 20))
			put(xy, Plane.airAtk, min(1, Float(u.airAtk) / 20))
			put(xy, Plane.groundDef, min(1, Float(u.groundDef) / 20))
			put(xy, Plane.airDef, min(1, Float(u.airDef) / 20))
			put(xy, Plane.mov, min(1, Float(u.mov) / 8))
			put(xy, Plane.rng, min(1, Float(u.rng) / 4))
			put(xy, Plane.ini, min(1, Float(u.ini) / 12))
		}

		globals[Global.prestige] = min(1, Float(me.prestige) / 4096)
		globals[Global.day] = min(1, Float(day) / 128)
		globals[Global.tier] = Float(me.tier) / 5
		globals[Global.baseLevel] = Float(me.baseLevel) / 8
		globals[Global.ownUnits] = min(1, Float(ownUnits) / 32)
		globals[Global.enemyUnits] = min(1, Float(enemyUnits) / 32)
		globals[Global.ownSettlements] = min(1, Float(ownSettlements) / 32)
		globals[Global.enemySettlements] = min(1, Float(enemySettlements) / 32)
		if case let .survive(team, day: deadline) = objective {
			globals[team == myTeam ? Global.mustSurvive : Global.mustAnnihilate] = 1
			globals[Global.deadline] = max(0, min(1, (Float(deadline) + 1 - Float(day)) / 128))
		}
		globals[Global.mapSize] = Float(map.size) / 32

		return SimObservation(planes: planes, globals: globals)
	}
}

extension Terrain {

	/// The one-hot observation plane for this tile, `nil` for `.none`.
	var plane: Int? {
		switch self {
		case .none: nil
		case .river: Plane.river
		case .sea: Plane.sea
		case .bridgeWE, .bridgeSN: Plane.bridge
		case .field: Plane.field
		case .forest: Plane.forest
		case .hill: Plane.hill
		case .forestHill: Plane.forestHill
		case .mountain: Plane.mountain
		case .city: Plane.city
		case .fort: Plane.fort
		case .airfield: Plane.airfield
		case .villageE, .villageN, .villageW, .villageS: Plane.village
		case .roadNW, .roadNE, .roadWE, .roadSN, .roadSW, .roadSE, .roadX: Plane.road
		}
	}
}
