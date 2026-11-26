import COR

typealias Unit = COR.Unit

typealias TacticalMode = SceneMode<TacticalState, Action, TacticalEvent, PresentationIntent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		.init(
			make: TacticalNodes.init,
			initialMenu: { _, state in state.sim.isFinished ? HQMenu().menu() : nil },
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
		!sim.isFinished && (sim.player.type == .ai || ui.autoBattle)
	}
}
