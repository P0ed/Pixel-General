@frozen public enum HQAction {
	case swap(Int, Int)
	case purchase(Int, Int)
	case sell(Int)
}

public extension HQState {

	mutating func reduce(_ action: HQAction) -> [HQEvent] {
		var events: [HQEvent] = []
		switch action {
		case .purchase(let t, let idx): purchase(t, idx, into: &events)
		case .sell(let idx): sell(idx, into: &events)
		case .swap(let src, let dst): swap(src, dst, into: &events)
		}
		return events
	}

	private mutating func purchase(_ t: Int, _ idx: Int, into events: inout [HQEvent]) {
		let u = shop[t]
		let cost = u.cost
		guard player.prestige >= cost, !units[idx].alive else { return }

		let unit = modifying(u) { u in u.reset() }
		player.prestige.decrement(by: cost)
		units[idx] = unit
		events.append(.spawn(idx.uid))
	}

	private mutating func sell(_ idx: Int, into events: inout [HQEvent]) {
		player.prestige.increment(by: units[idx].cost / 2)
		units[idx].hp = 0x0
		events.append(.remove(idx.uid))
	}

	private mutating func swap(_ src: Int, _ dst: Int, into events: inout [HQEvent]) {
		events.append(.remove(src.uid))
		events.append(.remove(dst.uid))

		let u = units[src]
		units[src] = units[dst]
		units[dst] = u

		if units[src].alive { events.append(.spawn(src.uid)) }
		if units[dst].alive { events.append(.spawn(dst.uid)) }
	}
}
