typealias TacticalMode = SceneMode<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		.init(
			make: TacticalNodes.init,
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
