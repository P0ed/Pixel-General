@frozen public enum StrategicAction {
	/// Launch an offensive against the enemy province at `XY`.
	case attack(XY)
	/// Launch specifically with the selected human army slot.
	case attackFrom(Int, XY)
	/// Raise the fortification of the owned province at `XY`.
	case build(BuildingType, at: XY)
	/// March the army in the slot to an `XY` within its move range.
	case move(Int, XY)
	/// Muster a new army on the owned province at `XY`.
	case found(XY)
	case endTurn
}

@frozen public enum StrategicEvent {
	case attack(Int, XY)
	case build(XY)
	case move(Int)
	case found(XY)
	case endTurn
}

public extension StrategicSim {

	mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		var events: [StrategicEvent] = []
		switch action {
		case .attack(let xy):
			if let slot = attackingArmy(at: xy) { events.append(.attack(slot, xy)) }
		case .attackFrom(let slot, let xy):
			let id = ArmyID(country: player.country, slot: slot)
			if canAttack(xy, with: id) { events.append(.attack(slot, xy)) }
		case .build(let b, let xy): return build(b, at: xy)
		case .move(let slot, let xy): move(slot, to: xy, into: &events)
		case .found(let xy): if canFound(at: xy) { found(at: xy); events.append(.found(xy)) }
		case .endTurn: endTurn(into: &events)
		}
		return events
	}

	private mutating func build(_ building: BuildingType, at xy: XY) -> [StrategicEvent] {
		guard canBuild(building, at: xy) else { return [] }
		let cost = buildingCost(building, above: provinces[xy][building], at: xy)
		guard player.prestige >= cost else { return [] }
		player.prestige.decrement(by: cost)
		provinces[xy][.fort] += 1
		return [.build(xy)]
	}

	private mutating func move(_ slot: Int, to xy: XY, into events: inout [StrategicEvent]) {
		guard (0 ..< 4).contains(slot), let steps = marchCost(by: slot, to: xy) else { return }
		let countryIndex = Int(player.country.rawValue)
		armies[countryIndex][slot].position = xy
		armies[countryIndex][slot].mp -= min(steps, armies[countryIndex][slot].mp)
		events.append(.move(slot))
	}

	private mutating func endTurn(into events: inout [StrategicEvent]) {
		turn += 1
		var upkeep: UInt16 = 0
		let countryIndex = Int(player.country.rawValue)
		for slot in 0 ..< 4 where armies[countryIndex][slot].active {
			if slot != 0, !hasCoreForce(slot) {
				// An emptied roster disbands the army and frees the slot.
				armies[countryIndex][slot].active = false
				continue
			}
			armies[countryIndex][slot].mp = Army.moveSpeed
			upkeep += Army.upkeep(slot: slot)
		}
		player.prestige.decrement(by: upkeep)
		runStrategicAI()
		events.append(.endTurn)
	}
}
