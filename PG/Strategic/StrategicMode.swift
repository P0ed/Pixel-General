import COR

typealias StrategicMode = SceneMode<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>
typealias StrategicScene = Scene<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>

extension StrategicMode {

	static var strategic: Self {
		StrategicMode(
			make: StrategicNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.pay(action) ? state.reduce(action) : [] },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state.sim); core.save() }
		)
	}
}

extension StrategicState {

	/// Charges the campaign treasury for actions with a prestige cost (fort
	/// builds) before the sim reduces them — the treasury lives in `Core.hq`,
	/// which the sim can't see. Returns `false` to drop an unaffordable action.
	@MainActor func pay(_ action: StrategicAction) -> Bool {
		guard case .build(let b, let xy) = action, sim.canBuild(b, at: xy) else { return true }
		return core.payForFort(StrategicSim.fortCost(above: sim.provinces[xy][.fort]))
	}

	@MainActor
	var status: Status {
		let xy = ui.cursor
		let province = sim.provinces[xy]
		return Status(
			text: .makeStatus(pad: 12) { add in
				add("\(sim.owner[xy])")
				add("day: \(sim.turn + 1)")
				if let slot = sim.armyIndex(at: xy) {
					add("army \(slot + 1): \(unitCount(slot))/16 mp \(sim.armies[slot].mp)")
				}
				guard sim.owner[xy] != .none else { return }
				if province[.fort] > 0 { add("fort: \(province[.fort])") }
				for t in BuildingType.allCases where t != .fort && province[t] > 0 {
					add("\(t.tag) \(province[t])")
				}
			},
			action: actionHint
		)
	}

	/// Alive units in an army slot — the main army's roster lives in
	/// `Core.hq`, the others in the sim.
	@MainActor private func unitCount(_ slot: Int) -> Int {
		if slot == 0 {
			core.hq.units.reduce(into: 0) { n, u in n += u.alive ? 1 : 0 }
		} else {
			sim.armies[slot].units.reduce(into: 0) { n, u in n += u.alive ? 1 : 0 }
		}
	}

	private var actionHint: String {
		let xy = ui.cursor
		var hints: [String] = []
		if let slot = ui.selected, let cost = sim.marchCost(by: slot, to: xy), cost > 0 {
			hints.append("A: move (\(cost))")
		} else if sim.canAttack(xy) {
			hints.append("A: attack")
		} else if sim.armyIndex(at: xy) != nil {
			hints.append("A: select")
		}
		if sim.canBuild(.fort, at: xy) {
			hints.append("B: fortify (\(StrategicSim.fortCost(above: sim.provinces[xy][.fort])))")
		}
		if let slot = sim.armyIndex(at: xy) {
			hints.append("C: army \(slot + 1)")
		} else if sim.canFound(at: xy) {
			hints.append("C: found army")
		}
		return hints.joined(separator: "  ")
	}
}

private extension BuildingType {

	/// Short status-string tag for a factory level readout.
	var tag: String {
		switch self {
		case .civil: "civ"
		case .fort: "fort"
		case .army: "army"
		case .armor: "armor"
		case .aa: "aa"
		case .air: "air"
		case .uav: "uav"
		case .navy: "navy"
		}
	}
}
