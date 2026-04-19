enum HQAction {
	case swap(Int, Int)
	case purchase(Int, Int)
	case sell(Int)
	case nop
}

extension HQState {

	mutating func reduce(_ action: HQAction) -> [HQEvent] {
		switch action {
		case .purchase(let idx, let slot):
			purchase(idx, in: slot)
		case .sell(let idx):
			player.prestige.increment(by: units[idx].cost / 2)
			units[idx].hp = 0x0
			events.add(.remove(idx.uid))
		case .swap(let src, let dst):
			events.add(.remove(src.uid))
			events.add(.remove(dst.uid))

			let u = units[src]
			units[src] = units[dst]
			units[dst] = u

			if units[src].alive { events.add(.spawn(src.uid)) }
			if units[dst].alive { events.add(.spawn(dst.uid)) }
		default: break
		}

		defer { events.erase() }
		return events.map { _, e in e }
	}

	var shop: [Unit] { .shop(country: country) }
}
