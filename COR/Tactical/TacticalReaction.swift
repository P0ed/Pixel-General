public typealias TacticalReaction = Reaction<TacticalAction, TacticalEvent>

@frozen public enum TacticalAction: Equatable, BitwiseCopyable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resupply(UID)
	case purchase(Int, XY)
	case takeover(Country)
	case end
}

@frozen public enum TacticalEvent {
	case spawn(UID)
	case move(UID, Path)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case ruggedDefence(XY)
	case shop
	case menu
	case end
}

extension TacticalSim {

	public mutating func reduce(_ action: TacticalAction) -> [TacticalEvent] {
		var events: [TacticalEvent] = []
		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst, into: &events)
		case .move(let unit, let xy): move(unit: unit, to: xy, into: &events)
		case .embark(let u, let t): embark(unit: u, transport: t, into: &events)
		case .disembark(let t, let xy): disembark(unit: t, to: xy, into: &events)
		case .resupply(let u): resupply(unit: u, into: &events)
		case .purchase(let idx, let xy): buy(idx, at: xy, into: &events)
		case .takeover(let c): takeover(country: c)
		case .end: endTurn(into: &events)
		}
		return events
	}

	mutating func takeover(country: Country) {
		players.modifyEach { _, p in
			if p.country == country { p.type = .ai }
		}
	}
}

extension TacticalState {

	public mutating func reduce(_ action: TacticalAction) -> [TacticalEvent] {
		let events = sim.reduce(action)

		switch action {
		case .move(let uid, _), .attack(let uid, _):
			if sim.player.type == .human {
				let keep = sim.units[uid].alive && sim.units[uid].hasActions || sim.cargo[uid] != .none
				ui.selectedUnit = keep ? uid : .none
			}
		case .embark(_, let transport) where sim.player.type == .human:
			ui.selectedUnit = transport
		case .end:
			ui.selectedUnit = .none
		default:
			break
		}

		ui.selectable = ui.selectedUnit != .none && sim.units[ui.selectedUnit].canMove
		? sim.moves(for: ui.selectedUnit).setXY : nil

		return events
	}
}
