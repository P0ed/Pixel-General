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
	case end
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
