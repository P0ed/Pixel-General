import COR

extension TacticalState {

	@MainActor
	var status: Status {
		var status = if sim.player.type == .ai {
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
		} else {
			Status(
				text: "day \(sim.day)\n\(sim.map[ui.cursor])",
				flag: sim.control[ui.cursor].flag
			)
		}
		if case let .survive(team, day: deadline) = sim.objective {
			status.text = "Defense · \(team) through day \(deadline)\n" + status.text
		}
		return status
	}
}
