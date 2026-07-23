import COR

extension TacticalState {

	var status: Status {
		if sim.player.type == .remote {
			Status(text: "waiting for \(sim.player.country)", action: "day \(sim.day)")
		} else if sim.player.type != .human {
			Status(text: "\(sim.player.country) turn")
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
		} else if sim.map[ui.cursor].isSettlement {
			Status(
				text: "\(ui.cursor) \(sim.map[ui.cursor])",
				flag: sim.control[ui.cursor].flag
			)
		} else {
			Status(text: "\(ui.cursor) \(sim.map[ui.cursor])", action: "day \(sim.day)")
		}
	}
}
