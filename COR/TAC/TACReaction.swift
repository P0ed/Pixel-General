@frozen public enum Action: Equatable {
	case move(UID, XY)
	case embark(UID, UID)
	case disembark(UID, XY)
	case attack(UID, UID)
	case resupply(UID)
	case purchase(Int, XY, aux: Bool = false)
	case end
	case abandon
}

@frozen public enum Event {
	case spawn(UID)
	case move(UID, Path)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case ruggedDefence(XY)
	case end
}

extension TACState {

	/// Applies `action` — the only mutation of deterministic state.
	///
	/// An illegal action leaves the sim bitwise-unchanged and emits no events.
	/// The tactical AI checks the same legality predicates as the reducers.
	public mutating func reduce(_ action: Action) -> [Event] {
		var events: [Event] = []
		switch action {
		case .attack(let src, let dst): attack(src: src, dst: dst, into: &events)
		case .move(let unit, let xy): move(unit: unit, to: xy, into: &events)
		case .embark(let u, let t): embark(unit: u, transport: t, into: &events)
		case .disembark(let t, let xy): disembark(unit: t, to: xy, into: &events)
		case .resupply(let u): resupply(unit: u, into: &events)
		case .purchase(let idx, let xy, let aux): buy(idx, at: xy, aux: aux, into: &events)
		case .end: endTurn(into: &events)
		case .abandon: break
		}
		return events
	}
}
