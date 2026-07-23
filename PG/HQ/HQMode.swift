import COR

typealias HQMode = SceneMode<HQState, HQAction, HQEvent, HQPresentationIntent, HQNodes>
typealias HQScene = Scene<HQState, HQAction, HQEvent, HQPresentationIntent, HQNodes>

extension HQMode {

	static var hq: Self {
		.init(
			make: HQNodes.init,
			input: { state, input in state.apply(input) },
			reduce: { state, action in state.reduce(action) },
			process: { event, nodes, state in await nodes.process(event, state) },
			present: { intent, nodes, state in await nodes.present(intent, state) },
			update: { nodes, state in nodes.update(state) },
			status: { state in state.status },
			mouse: { nodes, point in nodes.map.tile(at: point) },
			save: { state in core.store(state.sim); core.save() }
		)
	}
}

extension HQState {

	var status: Status {
		Status(
			text: ui.selected != .none
				? sim.units[ui.selected.index].status()
				: "prestige: \(sim.player.prestige)",
			action: actionHint
		)
	}

	private var actionHint: String {
		if ui.selected != .none {
			let xy = XY(ui.selected.index % 4, ui.selected.index / 4)
			let upgrade = sim.upgrades(at: xy).isEmpty ? "" : "C: upgrade  "
			return upgrade + "D: sell"
		} else if sim.units[ui.cursor] == nil {
			return "C: shop"
		} else {
			return ""
		}
	}
}
