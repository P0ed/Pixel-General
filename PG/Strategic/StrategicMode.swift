typealias StrategicMode = SceneMode<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>
typealias StrategicScene = Scene<StrategicState, StrategicAction, StrategicEvent, StrategicNodes>

extension StrategicMode {

	static var strategic: Self {
		.init(
			make: StrategicNodes.init,
			input: { state, input in state.apply(input) },
			update: { nodes, state in nodes.update(state) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.mouse(event) },
			save: { state in core.store(state) }
		)
	}
}
