typealias HQMode = SceneMode<HQState, HQUI, HQAction, HQEvent, HQNodes>
typealias HQScene = Scene<HQState, HQUI, HQAction, HQEvent, HQNodes>

extension HQMode {

	static var hq: Self {
		.init(
			make: HQNodes.init,
			input: { state, ui, input in ui.apply(input, state) },
			update: { nodes, state, ui in nodes.update(state, ui) },
			reduce: { state, ui, action in state.reduce(action) },
			process: { event, nodes, state, ui in await nodes.process(event, state, ui) },
			status: { state, ui in state.status(ui) },
			mouse: { nodes, event in nodes.mouse(event) },
			save: { state in core.store(state) }
		)
	}
}
