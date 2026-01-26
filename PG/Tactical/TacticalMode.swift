typealias TacticalMode = SceneMode<TacticalState, TacticalEvent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalEvent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		.init(
			make: TacticalNodes.init,
			inputable: { state in state.inputable },
			input: { state, input in state.apply(input) },
			update: { state, nodes in nodes.update(state: state) },
			reducible: { state in state.reducible },
			reduce: { state in state.reduce() },
			process: { scene, events in await scene.process(events: events) },
			status: { state in (state.statusText, state.globalText) },
			mouse: { nodes, event in nodes.mouse(event: event) },
			save: { state in core.store(tactical: state) }
		)
	}
}
