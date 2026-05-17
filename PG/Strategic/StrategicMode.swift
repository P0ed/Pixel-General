typealias StrategicMode = SceneMode<StrategicState, StrategicUI, StrategicAction, StrategicEvent, StrategicNodes>
typealias StrategicScene = Scene<StrategicState, StrategicUI, StrategicAction, StrategicEvent, StrategicNodes>

extension StrategicMode {

	static var strategic: Self {
		.init(
			make: StrategicNodes.init,
			input: { state, ui, input in ui.apply(input, state) },
			update: { nodes, state, ui in nodes.update(state) },
			reduce: { state, ui, action in state.reduce(action) },
			process: { event, nodes, state, ui in await nodes.process(event, state) },
			status: { state, ui in state.status },
			mouse: { nodes, event in nodes.mouse(event) },
			save: { state in core.store(state) }
		)
	}
}
