/// A campaign field army: up to 16 units at a map position, moving a few
/// tiles per turn. Fully inline for raw encode/decode (`Unit` predates
/// `BitwiseCopyable` and doesn't declare it, so this struct can't either).
@frozen public struct Army {
	/// Roster for army slots 1...3. Slot 0 is the main army: its roster
	/// lives in `Core.hq.units` and this field stays zeroed.
	public var units: [16 of Unit]
	public var position: XY
	/// Tiles this army may still move this turn.
	public var mp: UInt8
	public var active: Bool

	public init() {
		units = .init(repeating: Unit())
		position = .zero
		mp = 0
		active = false
	}
}

public extension Army {

	/// Tiles an army covers per strategic turn.
	static var moveSpeed: UInt8 { 2 }

	/// Chebyshev distance within which a defender's army reinforces a
	/// battle as aux forces.
	static var auxJoinRange: Int { 2 }

	/// Per-turn prestige upkeep — the main army is free, each new army
	/// costs more to maintain.
	static func upkeep(slot: Int) -> UInt16 {
		UInt16(50 * slot)
	}
}

public extension StrategicSim {

	/// The active army occupying `xy`; at most one per tile.
	func armyIndex(at xy: XY) -> Int? {
		// The `armies` locals in these helpers are deliberate: looping over
		// projections of the huge inline sim sends the noncopyable checker
		// into a tailspin (hour-long compiles); a copy of the small
		// copyable array keeps it out of the loop.
		let armies = armies
		for i in 0 ..< 4 where armies[i].active && armies[i].position == xy {
			return i
		}
		return nil
	}

	/// Slot 0 fights with the `Core.hq` roster and always counts as manned;
	/// other slots need at least one alive rostered unit.
	func hasCoreForce(_ slot: Int) -> Bool {
		guard slot != 0 else { return true }
		let army = armies[slot]
		for i in 0 ..< 16 where army.units[i].alive {
			return true
		}
		return false
	}

	/// A new army can muster on an own land tile with no army on it while a
	/// free slot exists and no battle is running.
	func canFound(at xy: XY) -> Bool {
		owner.contains(xy)
			&& owner[xy] == human
			&& battle == nil
			&& armyIndex(at: xy) == nil
			&& freeArmySlot != nil
	}

	var freeArmySlot: Int? {
		let armies = armies
		for i in 0 ..< 4 where !armies[i].active {
			return i
		}
		return nil
	}

	/// Tiles the army can move to this turn: a BFS through own land over
	/// `.n4`, one mp per step, skipping tiles held by other armies.
	func reachable(by slot: Int) -> SetXY {
		var result = SetXY.empty
		march(by: slot) { xy, _ in result[xy] = true }
		return result
	}

	/// Steps the army needs to reach `target` this turn; `nil` when out of
	/// range.
	func marchCost(by slot: Int, to target: XY) -> UInt8? {
		var cost: UInt8?
		march(by: slot) { xy, steps in
			if xy == target { cost = steps }
		}
		return cost
	}

	private func march(by slot: Int, _ visit: (XY, UInt8) -> Void) {
		let army = armies[slot]
		guard army.active, army.mp > 0 else { return }
		var seen = SetXY.empty
		var frontier = [army.position]
		seen[army.position] = true
		for step in 1 ... Int(army.mp) {
			var next: [XY] = []
			for xy in frontier {
				let n4 = xy.n4
				for i in 0 ..< n4.count {
					let n = n4[i]
					guard owner.contains(n), owner[n] == human, !seen[n] else { continue }
					seen[n] = true
					guard armyIndex(at: n) == nil else { continue }
					visit(n, UInt8(step))
					next.append(n)
				}
			}
			frontier = next
		}
	}

	/// An army slot's roster. Method access on purpose: projecting `armies`
	/// through `strategic?.` chains makes the noncopyable checker
	/// destructure the whole sim (see `armyIndex`).
	func roster(_ slot: Int) -> [16 of Unit] {
		armies[slot].units
	}

	mutating func setRoster(_ units: [16 of Unit], slot: Int) {
		armies[slot].units = units
	}

	/// The slot fighting the running battle (`battleArmy` as `Int`).
	func fightingSlot() -> Int {
		Int(battleArmy)
	}

	/// Marks the battle context for an offensive `slot` launches at `tile`:
	/// attacking spends the army's remaining movement.
	mutating func launchBattle(at tile: XY, by slot: Int) {
		battle = tile
		battleArmy = UInt8(slot)
		armies[slot].mp = 0
	}

	/// Disbands a side army whose roster came back from a battle empty.
	mutating func disbandIfWipedOut(_ slot: Int) {
		if slot > 0, !hasCoreForce(slot) {
			armies[slot].active = false
		}
	}

	/// Activates a free slot at `xy` with an empty roster. The army moves
	/// from the next turn on.
	mutating func found(at xy: XY) {
		guard canFound(at: xy), let slot = freeArmySlot else { return }
		armies[slot] = modifying(Army()) { a in
			a.position = xy
			a.active = true
		}
	}

	/// The defender's nearest active army within `Army.auxJoinRange` of
	/// `tile` — excluding the one fighting as the core force — joins the
	/// battle as aux forces. Armies belong to the human country, so this
	/// only fires when the human defends. Restricted to slots 1...3: the
	/// main army's roster lives in `Core.hq`, invisible to the sim.
	func auxReinforcement(for country: Country, near tile: XY) -> [Unit] {
		guard country == human else { return [] }
		let armies = armies
		var best: Int?
		var bestDistance = Army.auxJoinRange + 1
		for i in 1 ..< 4 where armies[i].active && i != Int(battleArmy) {
			let p = armies[i].position
			let d = max(abs(p.x - tile.x), abs(p.y - tile.y))
			if d < bestDistance, hasCoreForce(i) {
				best = i
				bestDistance = d
			}
		}
		guard let best else { return [] }
		var units: [Unit] = []
		for i in 0 ..< 16 where armies[best].units[i].alive {
			units.append(armies[best].units[i].aux)
		}
		return units
	}
}
