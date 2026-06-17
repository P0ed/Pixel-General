import COR

typealias StrategicMode = SceneMode<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>
typealias StrategicScene = Scene<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>

extension StrategicMode {

	static var strategic: Self {
		StrategicMode(
			make: StrategicNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state); core.save() }
		)
	}
}

extension StrategicState {

	var status: Status {
		Status(
			text: .makeStatus { add in
				add("\(sim.owner[ui.cursor])")
				add("day: \(sim.turn + 1)")
			},
			action: sim.canAttack(ui.cursor) ? "A: attack" : ""
		)
	}
}
