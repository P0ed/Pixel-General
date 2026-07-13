@frozen public enum StrategicAction {
	/// Launch an offensive against the enemy province at `XY`.
	case attack(XY)
	/// Raise the fortification of the owned province at `XY`.
	case build(BuildingType, at: XY)
	/// March the army in the slot to an `XY` within its move range.
	case move(Int, XY)
	/// Muster a new army on the owned province at `XY`.
	case found(XY)
	case endTurn
}

@frozen public enum StrategicEvent {
	case attack(XY)
	case build(XY)
	case move(Int)
	case found(XY)
	case endTurn
}

public extension StrategicSim {

	mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		var events: [StrategicEvent] = []
		switch action {
		case .attack(let xy): if canAttack(xy) { events.append(.attack(xy)) }
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
		armies[slot].position = xy
		armies[slot].mp -= min(steps, armies[slot].mp)
		events.append(.move(slot))
	}

	private mutating func endTurn(into events: inout [StrategicEvent]) {
		turn += 1
		var upkeep: UInt16 = 0
		for i in 0 ..< 4 where armies[i].active {
			if i != 0, !hasCoreForce(i) {
				// An emptied roster disbands the army and frees the slot.
				armies[i].active = false
				continue
			}
			armies[i].mp = Army.moveSpeed
			upkeep += Army.upkeep(slot: i)
		}
		player.prestige.decrement(by: upkeep)
		events.append(.endTurn)
	}
}
