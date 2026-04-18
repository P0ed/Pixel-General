typealias HQMode = SceneMode<HQState, HQAction, HQEvent, HQNodes>
typealias HQScene = Scene<HQState, HQAction, HQEvent, HQNodes>

extension HQMode {

	static var hq: Self {
		.init(
			make: HQNodes.init,
			input: { state, input in state.apply(input) },
			update: { state, nodes in nodes.update(state: state) },
			reduce: { state, action in state.reduce(action) },
			process: { state, events, nodes in await nodes.process(events, state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.mouse(event: event) },
			save: { state in core.store(state) }
		)
	}
}
