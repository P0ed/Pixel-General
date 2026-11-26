import COR

typealias Unit = COR.Unit

typealias TacticalMode = SceneMode<TacticalState, TacticalAction, TacticalEvent, TacticalPresentationIntent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalAction, TacticalEvent, TacticalPresentationIntent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		.init(
			make: TacticalNodes.init,
			input: { state, input in state.apply(input) },
			next: { [ai = AI.heuristic] state in state.auto ? ai(state.sim) : nil },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			present: { intent, nodes, state in await nodes.present(intent, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			cameraPosition: { state in state.ui.camera.point },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state.sim); core.save() }
		)
	}
}

private extension TacticalState {

	var auto: Bool {
		sim.player.type == .ai || ui.autoBattle
	}
}
