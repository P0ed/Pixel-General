public typealias HQReaction = Reaction<HQAction, HQEvent>

@frozen public enum HQAction {
	case swap(Int, Int)
	case purchase(Int, Int)
	case sell(Int)
	case upgrade(Int, UnitModel)
}

@frozen public enum HQEvent {
	case move(UID, XY)
	case spawn(UID)
	case remove(UID)
	case shop
	case upgrade(UID)
	case menu
}

public extension HQSim {

	mutating func reduce(_ action: HQAction) -> [HQEvent] {
		var events: [HQEvent] = []
		switch action {
		case .purchase(let t, let idx): purchase(t, idx, into: &events)
		case .sell(let idx): sell(idx, into: &events)
		case .swap(let src, let dst): swap(src, dst, into: &events)
		case .upgrade(let idx, let model): upgrade(idx, model, into: &events)
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

	private mutating func upgrade(_ idx: Int, _ model: UnitModel, into events: inout [HQEvent]) {
		let current = units[idx]
		guard current.alive,
		      Shop(country: country, tier: player.tier)
			.upgrades(for: current).contains(where: { $0.model == model })
		else { return }

		let cost = current.upgradeCost(to: model)
		guard player.prestige >= cost else { return }

		player.prestige.decrement(by: cost)
		units[idx] = current.upgraded(to: model)
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

extension HQState {

	/// Mirrors `TacticalState.reduce`: the mode always reduces through `State`,
	/// which delegates the deterministic mutation to `sim`. HQ has no UI to
	/// reconcile afterwards.
	public mutating func reduce(_ action: HQAction) -> [HQEvent] {
		sim.reduce(action)
	}
}
