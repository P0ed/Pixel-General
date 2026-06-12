import COR

extension TacticalState {

	var status: Status {
		if player.type == .remote {
			Status(text: "waiting for \(player.country)", action: "day \(day)")
		} else if player.type != .human {
			Status(text: "\(player.country) turn")
		} else if selectedUnit != .none {
			Status(
				text: units[selectedUnit].status(cargo: cargo[selectedUnit] != .none),
				flag: units[selectedUnit].country.flag
			)
		} else if map[cursor].isSettlement {
			Status(
				text: "\(cursor) \(map[cursor])",
				flag: control[cursor].flag
			)
		} else {
			Status(text: "\(cursor) \(map[cursor])", action: "day \(day)")
		}
	}
}
