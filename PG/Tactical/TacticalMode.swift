import COR

typealias Unit = COR.Unit

typealias TacticalMode = SceneMode<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>

extension TacticalMode {

	static var tactical: Self {
		let ai = TacticalState.ai
		return .init(
			make: TacticalNodes.init,
			input: { state, input in state.apply(input) },
			ai: { state in
				if let net { return net.nextAction(state, ai) }
				return ai(state)
			},
			relay: { state, action in net?.relay(state, action) ?? false },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, event in nodes.map.tile(at: event) },
			save: { state in core.store(state); core.save(auto: true) }
		)
	}
}
