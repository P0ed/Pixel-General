/// A stable reference to one of a country's four campaign army slots.
@frozen public struct ArmyID: Equatable, Hashable, BitwiseCopyable {
	public var country: Country
	public var slot: UInt8

	public init(country: Country, slot: Int) {
		precondition((0 ..< 4).contains(slot), "army slot out of range")
		self.country = country
		self.slot = UInt8(slot)
	}

	public var index: Int { Int(slot) }
}

/// A campaign field army: up to 16 units at a map position, moving a few
/// tiles per turn. Fully inline for raw encode/decode (`Unit` predates
/// `BitwiseCopyable` and doesn't declare it, so this struct can't either).
@frozen public struct Army {
	public var units: [16 of Unit]
	public var position: XY
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

	static var moveSpeed: UInt8 { 2 }

	static var defRange: Int { 2 }

	/// Per-turn prestige upkeep — the main army is free, each new army
	/// costs more to maintain.
	static func upkeep(slot: Int) -> UInt16 {
		UInt16(50 * slot)
	}

	/// Strategic strength deliberately uses hit points, rather than unit cost:
	/// three intact units are a literal 3:1 advantage over one intact unit.
	var strength: Int {
		units.reduce(into: 0) { result, unit in
			if unit.alive { result += Int(unit.hp) }
		}
	}
}

public extension StrategicSim {

	func army(_ id: ArmyID) -> Army {
		armies[Int(id.country.rawValue)][id.index]
	}

	/// The active army occupying `xy`, in deterministic country/slot order.
	func army(at xy: XY) -> ArmyID? {
		for country in Country.allCases where country != .none {
			let countryIndex = Int(country.rawValue)
			for slot in 0 ..< 4 {
				let army = armies[countryIndex][slot]
				if army.active, army.position == xy {
					return ArmyID(country: country, slot: slot)
				}
			}
		}
		return nil
	}

	func armyIndex(at xy: XY, for country: Country) -> Int? {
		let countryIndex = Int(country.rawValue)
		for slot in 0 ..< 4 {
			let army = armies[countryIndex][slot]
			if army.active, army.position == xy { return slot }
		}
		return nil
	}

	/// Human-country compatibility helper used by the strategic UI/HQ flow.
	func armyIndex(at xy: XY) -> Int? {
		armyIndex(at: xy, for: player.country)
	}

	func armyIsActive(_ slot: Int, for country: Country) -> Bool {
		(0 ..< 4).contains(slot) && armies[Int(country.rawValue)][slot].active
	}

	func armyIsActive(_ slot: Int) -> Bool {
		armyIsActive(slot, for: player.country)
	}

	func hasCoreForce(_ slot: Int, for country: Country) -> Bool {
		guard (0 ..< 4).contains(slot) else { return false }
		return armies[Int(country.rawValue)][slot].strength > 0
	}

	func hasCoreForce(_ slot: Int) -> Bool {
		hasCoreForce(slot, for: player.country)
	}

	func canFound(at xy: XY, for country: Country) -> Bool {
		owner.contains(xy)
			&& owner[xy] == country
			&& battle == nil
			&& army(at: xy) == nil
			&& freeArmySlot(for: country) != nil
	}

	func canFound(at xy: XY) -> Bool {
		canFound(at: xy, for: player.country)
	}

	func freeArmySlot(for country: Country) -> Int? {
		let countryIndex = Int(country.rawValue)
		for slot in 0 ..< 4 where !armies[countryIndex][slot].active {
			return slot
		}
		return nil
	}

	var freeArmySlot: Int? {
		freeArmySlot(for: player.country)
	}

	/// Tiles the army can move to this turn: a BFS through its country's land
	/// over `.n4`, one mp per step, skipping every occupied army tile.
	func reachable(by slot: Int, for country: Country) -> SetXY {
		var result = SetXY.empty
		march(by: slot, for: country) { xy, _ in result[xy] = true }
		return result
	}

	func reachable(by slot: Int) -> SetXY {
		reachable(by: slot, for: player.country)
	}

	/// Steps the army needs to reach `target` this turn; `nil` when out of
	/// range.
	func marchCost(by slot: Int, for country: Country, to target: XY) -> UInt8? {
		var cost: UInt8?
		march(by: slot, for: country) { xy, steps in
			if xy == target { cost = steps }
		}
		return cost
	}

	func marchCost(by slot: Int, to target: XY) -> UInt8? {
		marchCost(by: slot, for: player.country, to: target)
	}

	private func march(by slot: Int, for country: Country, _ visit: (XY, UInt8) -> Void) {
		guard (0 ..< 4).contains(slot) else { return }
		let fieldArmy = armies[Int(country.rawValue)][slot]
		guard fieldArmy.active, fieldArmy.mp > 0 else { return }
		var seen = SetXY.empty
		var frontier = [fieldArmy.position]
		seen[fieldArmy.position] = true
		for step in 1 ... Int(fieldArmy.mp) {
			var next: [XY] = []
			for xy in frontier {
				let n4 = xy.n4
				for i in 0 ..< n4.count {
					let n = n4[i]
					guard owner.contains(n), owner[n] == country, !seen[n] else { continue }
					seen[n] = true
					guard army(at: n) == nil else { continue }
					visit(n, UInt8(step))
					next.append(n)
				}
			}
			frontier = next
		}
	}

	/// An army slot's roster. Method access avoids projecting the entire
	/// country-keyed inline store through optional `StrategicSim` values.
	func roster(_ slot: Int, for country: Country) -> [16 of Unit] {
		armies[Int(country.rawValue)][slot].units
	}

	func roster(_ slot: Int) -> [16 of Unit] {
		roster(slot, for: player.country)
	}

	mutating func setRoster(_ units: [16 of Unit], slot: Int, for country: Country) {
		armies[Int(country.rawValue)][slot].units = units
	}

	mutating func setRoster(_ units: [16 of Unit], slot: Int) {
		setRoster(units, slot: slot, for: player.country)
	}

	/// The human army slot fighting the running tactical battle.
	func fightingSlot() -> Int {
		Int(battleArmy)
	}

	/// Marks the battle context for a human offensive; attacking spends the
	/// army's remaining movement.
	mutating func launchBattle(at tile: XY, by slot: Int) {
		battle = tile
		battleArmy = UInt8(slot)
		armies[Int(player.country.rawValue)][slot].mp = 0
	}

	/// Disbands a side army whose roster came back from a battle empty.
	mutating func disbandIfWipedOut(_ slot: Int, for country: Country) {
		if slot > 0, !hasCoreForce(slot, for: country) {
			armies[Int(country.rawValue)][slot].active = false
		}
	}

	mutating func disbandIfWipedOut(_ slot: Int) {
		disbandIfWipedOut(slot, for: player.country)
	}

	/// Activates a free slot at `xy`. Human armies begin empty for HQ editing;
	/// AI callers may provide a prepared inline roster.
	mutating func found(at xy: XY, for country: Country, units: [16 of Unit]) {
		guard canFound(at: xy, for: country), let slot = freeArmySlot(for: country) else { return }
		armies[Int(country.rawValue)][slot] = modifying(Army()) { army in
			army.units = units
			army.position = xy
			army.active = true
		}
	}

	mutating func found(at xy: XY, for country: Country) {
		found(at: xy, for: country, units: .init(repeating: Unit()))
	}

	mutating func found(at xy: XY) {
		found(at: xy, for: player.country)
	}

	/// The nearest manned army within `Army.defRange` is the country's core
	/// force for a tactical defence.
	func defendingArmy(for country: Country, near tile: XY) -> ArmyID? {
		let countryIndex = Int(country.rawValue)
		var best: Int?
		var bestDistance = Army.defRange + 1
		for slot in 0 ..< 4 {
			let army = armies[countryIndex][slot]
			guard army.active else { continue }
			let distance = max(abs(army.position.x - tile.x), abs(army.position.y - tile.y))
			if distance < bestDistance, hasCoreForce(slot, for: country) {
				best = slot
				bestDistance = distance
			}
		}
		return best.map { ArmyID(country: country, slot: $0) }
	}

	/// Living units from the nearest defending army remain core units. Factory
	/// totals are the sole source of campaign auxiliary forces.
	func defendingCore(for country: Country, near tile: XY) -> [Unit] {
		guard let army = defendingArmy(for: country, near: tile) else { return [] }
		var units: [Unit] = []
		let roster = roster(army.index, for: country)
		for index in roster.indices where roster[index].alive {
			units.append(roster[index])
		}
		return units
	}
}
