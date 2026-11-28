import COR

extension TACSceneState {

	@MainActor
	var status: Status {
		if tac.isFinished {
			Status(flag: core.hq.country.flag)
		} else if tac.player.type == .ai {
			Status(flag: tac.player.country.flag)
		} else if ui.selectedUnit != .none {
			Status(
				text: tac.units[ui.selectedUnit].status(
					friendly: tac.units[ui.selectedUnit].country.team == tac.player.country.team,
					cargo: tac.cargo[ui.selectedUnit] != .none
						? tac.units[tac.cargo[ui.selectedUnit]].typeDescription
						: nil
				),
				flag: tac.units[ui.selectedUnit].country.flag
			)
		} else {
			Status(
				text: "day \(tac.day)\n\(tac.map[ui.cursor])",
				flag: tac.control[ui.cursor].flag
			)
		}
	}
}
