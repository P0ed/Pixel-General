typealias HQMode = SceneMode<HQState, HQAction, HQEvent, HQNodes>
typealias HQScene = Scene<HQState, HQAction, HQEvent, HQNodes>

extension HQMode {

	static var hq: Self {
		.init(
			make: HQNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.map.tile(at: event) },
			save: { state in core.store(state) }
		)
	}
}
