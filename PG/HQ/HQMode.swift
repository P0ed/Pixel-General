typealias HQMode = SceneMode<HQState, Void, HQEvent, HQNodes>
typealias HQScene = Scene<HQState, Void, HQEvent, HQNodes>

extension HQMode {

	static var hq: Self {
		.init(
			make: HQNodes.init,
			input: { state, input in state.apply(input) },
			update: { state, nodes in nodes.update(state: state) },
			reduce: { state, _ in state.reduce() },
			process: { state, events, nodes in await nodes.process(events, state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.mouse(event: event) },
			save: { state in core.store(state) }
		)
	}
}
