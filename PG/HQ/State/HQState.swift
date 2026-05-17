struct HQState: ~Copyable {
	var map = Map<Terrain>(size: 4, zero: .field)
	var player: Player
	var units: [16 of Unit]
	var events: CArray<16, HQEvent> = .init(tail: .menu)
}

/// Session/UI state for the HQ scene. Owned by `Scene`, never persisted.
struct HQUI {
	var cursor: XY = .zero
	var selected: UID?
}

extension HQState {

	var country: Country { player.country }

	func status(_ ui: borrowing HQUI) -> Status {
		Status(
			text: ui.selected.map { units[$0.index].status } ?? .makeStatus { add in
				add("prestige: \(player.prestige)")
			},
			action: .init({
				if ui.selected != nil {
					"C: sell"
				} else if units[ui.cursor] == nil {
					"C: shop"
				} else {
					""
				}
			}())
		)
	}
}
