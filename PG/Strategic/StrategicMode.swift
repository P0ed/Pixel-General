import COR

typealias StrategicMode = SceneMode<StrategicState, StrategicAction, StrategicEvent, StrategicPresentationIntent, StrategicNodes>
typealias StrategicScene = Scene<StrategicState, StrategicAction, StrategicEvent, StrategicPresentationIntent, StrategicNodes>

extension StrategicMode {

	static var strategic: Self {
		StrategicMode(
			make: StrategicNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			present: { intent, nodes, state in await nodes.present(intent, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			cameraPosition: { state in state.ui.camera.point },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state.sim); core.save() }
		)
	}
}

extension StrategicState {

	@MainActor
	var status: Status {
		let xy = ui.cursor
		let province = sim.provinces[xy]
		return Status(
			text: .makeStatus(pad: 12) { add in
				add("\(sim.owner[xy])")
				add("day: \(sim.turn + 1)")
				if let slot = sim.armyIndex(at: xy) {
					add("\(unitCount(slot))/16 mp \(sim.armies[slot].mp)")
				}
				guard sim.owner[xy] != .none else { return }
				for t in BuildingType.allCases where province[t] > 0 {
					add("\(t.tag) \(province[t])")
				}
			},
			action: actionHint
		)
	}

	/// Alive units in an army slot.
	private func unitCount(_ slot: Int) -> Int {
		sim.armies[slot].units.reduce(into: 0) { n, u in n += u.alive ? 1 : 0 }
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
			hints.append("B: fortify (\(sim.buildingCost(.fort, above: sim.provinces[xy][.fort], at: xy)))")
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
