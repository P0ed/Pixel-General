import COR

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
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state); core.save() }
		)
	}
}

extension HQState {

	var status: Status {
		Status(
			text: ui.selected != .none ? sim.units[ui.selected.index].status() : .makeStatus { add in
				add("prestige: \(sim.player.prestige)")
			},
			action: {
				if ui.selected != .none {
					"C: sell"
				} else if sim.units[ui.cursor] == nil {
					"C: shop"
				} else {
					""
				}
			}()
		)
	}
}
