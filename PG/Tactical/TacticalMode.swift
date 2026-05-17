typealias TacticalMode = SceneMode<TacticalState, TacticalUI, TacticalAction, TacticalEvent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalUI, TacticalAction, TacticalEvent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		.init(
			make: TacticalNodes.init,
			input: { state, ui, input in ui.apply(input, state) },
			update: { nodes, state, ui in nodes.update(state, ui) },
			reduce: { state, ui, action in state.reduce(action, ui: &ui) },
			process: { event, nodes, state, ui in await nodes.process(event, state, ui) },
			status: { state, ui in state.status(ui) },
			mouse: { nodes, event in nodes.mouse(event) },
			auto: { state in state.player.type == .ai ? state.runAI() : nil },
			live: { input in switch input { case .pan, .scale: true; default: false } },
			liveUpdate: { nodes, state, ui in nodes.updateView(state, ui) },
			save: { state in core.store(state) }
		)
	}
}
