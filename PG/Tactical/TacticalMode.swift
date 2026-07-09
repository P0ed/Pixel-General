import Foundation
import COR

typealias Unit = COR.Unit

typealias TacticalMode = SceneMode<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>
typealias TacticalScene = Scene<TacticalState, TacticalAction, TacticalEvent, TacticalNodes>

extension LSTMWeights {

	/// The shipped opponent weights; `nil` (→ heuristic fallback) when the
	/// resource is missing or fails `spec` validation.
	static let bundled: LSTMWeights? = Bundle.main
		.url(forResource: "policy", withExtension: "pgw")
		.flatMap { url in try? Data(contentsOf: url) }
		.flatMap(LSTMWeights.init(data:))
}

extension TacticalMode {

	static var tactical: Self {
		let heuristic = AI.heuristic
		let lstm = AI.lstm(.bundled)
		return .init(
			make: TacticalNodes.init,
			input: { state, input in state.apply(input) },
			ai: { state in
				let ai = settings.aiKind > 0 ? lstm : heuristic
				if let net { return net.nextAction(state.sim, ai) }
				return ai(state.sim)
			},
			relay: { state, action in net?.relay(state.sim, action) ?? false },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state.sim); core.save() }
		)
	}
}
