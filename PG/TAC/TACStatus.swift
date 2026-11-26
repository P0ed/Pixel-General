import COR

extension TacticalState {

	@MainActor
	var status: Status {
		if sim.isFinished {
			Status(flag: core.hq.country.flag)
		} else if sim.player.type == .ai {
			Status(flag: sim.player.country.flag)
		} else if ui.selectedUnit != .none {
			Status(
				text: sim.units[ui.selectedUnit].status(
					friendly: sim.units[ui.selectedUnit].country.team == sim.player.country.team,
					cargo: sim.cargo[ui.selectedUnit] != .none
						? sim.units[sim.cargo[ui.selectedUnit]].typeDescription
						: nil
				),
				flag: sim.units[ui.selectedUnit].country.flag
			)
		} else {
			Status(
				text: "day \(sim.day)\n\(sim.map[ui.cursor])",
				flag: sim.control[ui.cursor].flag
			)
		}
	}
}
