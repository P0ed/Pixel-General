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

extension TacticalAction {

	func cameraFocus(in sim: borrowing TacticalSim) -> XY? {
		switch self {
		case .move(let uid, _), .embark(let uid, _), .resupply(let uid):
			let xy = sim.position[uid]
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .disembark(_, let xy):
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .attack(let src, let dst):
			let s = sim.position[src], d = sim.position[dst]
			return sim.isVisibleToHuman(s) ? s : sim.isVisibleToHuman(d) ? d : nil
		case .purchase, .takeover, .end:
			return nil
		}
	}
}

extension TacticalSim {

	/// Applies `action` — the only mutation of deterministic state.
	///
	/// Contract: an **illegal action leaves the sim bitwise-unchanged** and
	/// emits no events. Three subsystems rely on that no-op guarantee: the
	/// LSTM masks use "state mutated" as their legality oracle
	/// (`Tests/PolicyTests`), the multiplayer host re-validates client
	/// intents by simply applying them, and the AI drivers may propose
	/// actions that turn out illegal. Each reducer therefore opens with a
	/// guard on its legality predicate — `canMove` / `canAttack` /
	/// `canEmbark` / `canDisembark` / `canResupply` / `canBuy` — which is
	/// also what the action masks and the AIs consult. Keep new reducers on
	/// this pattern: one predicate, three consumers.
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

		if sim.player.type != .human, let focus = action.cameraFocus(in: sim) {
			let cam = ui.camera
			let across = (focus.x + focus.y) - (cam.x + cam.y)
			let depth = (focus.y - focus.x) - (cam.y - cam.x)
			if abs(across) > 8 * ui.scale || abs(depth) > 10 * ui.scale {
				ui.camera = focus.clamped(sim.map.size)
			}
		}

		ui.selectable = ui.selectedUnit != .none && sim.units[ui.selectedUnit].canMove
		? sim.moves(for: ui.selectedUnit).setXY : nil

		return events
	}
}
