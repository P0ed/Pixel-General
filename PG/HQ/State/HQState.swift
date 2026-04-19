struct HQState: ~Copyable {
	var player: Player
	var units: [16 of Unit]
	var events: CArray<16, HQEvent> = .init(tail: .menu)
	var cursor: XY = .zero
	var selected: UID?
}

extension HQState {

	var country: Country { player.country }

	var status: Status {
		Status(
			text: selected.map { units[$0.index].status } ?? .makeStatus { add in
				add("prestige: \(player.prestige)")
			},
			action: .init({
				if selected != nil {
					"sell []"
				} else if units[cursor] == nil {
					"shop []"
				} else {
					""
				}
			}())
		)
	}
}
