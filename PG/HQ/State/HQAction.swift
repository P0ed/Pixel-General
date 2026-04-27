enum HQAction {
	case swap(Int, Int)
	case purchase(Int, Int)
	case sell(Int)
}

extension HQState {

	mutating func reduce(_ action: HQAction?) -> [HQEvent] {
		switch action {
		case .purchase(let t, let idx): purchase(t, idx)
		case .sell(let idx): sell(idx)
		case .swap(let src, let dst): swap(src, dst)
		case .none: break
		}
		defer { events.erase() }
		return events.map { _, e in e }
	}

	var shop: [Unit] { .shop(country: country) }

	private mutating func purchase(_ t: Int, _ idx: Int) {
		let u = shop[t]
		let cost = u.cost
		guard player.prestige >= cost, !units[idx].alive else { return }

		let unit = modifying(u) { u in u.hp = u.maxHP }
		player.prestige.decrement(by: cost)
		units[idx] = unit
		events.add(.spawn(idx.uid))
	}

	private mutating func sell(_ idx: Int) {
		player.prestige.increment(by: units[idx].cost / 2)
		units[idx].hp = 0x0
		events.add(.remove(idx.uid))
	}

	private mutating func swap(_ src: Int, _ dst: Int) {
		events.add(.remove(src.uid))
		events.add(.remove(dst.uid))

		let u = units[src]
		units[src] = units[dst]
		units[dst] = u

		if units[src].alive { events.add(.spawn(src.uid)) }
		if units[dst].alive { events.add(.spawn(dst.uid)) }
	}
}
