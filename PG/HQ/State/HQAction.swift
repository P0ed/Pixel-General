enum HQAction {
	case swap(Int, Int)
	case purchase(Int, Int)
	case sell(Int)
	case nop
}

extension HQState {

	mutating func reduce(_ action: HQAction) -> [HQEvent] {
		defer { events.erase() }
		return events.map { _, e in e }
	}
}
