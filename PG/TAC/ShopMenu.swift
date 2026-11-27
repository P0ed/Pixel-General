import COR
import SpriteKit

extension Menu {

	static func shop(
		units: [Unit],
		auxiliary: [Unit]? = nil,
		auxiliaryOnly: Bool = false,
		offer: (Unit, Int, Bool) -> MenuItem
	) -> Self? {
		guard !units.isEmpty || auxiliary?.isEmpty == false else { return nil }

		func entries(_ units: [Unit], aux: Bool) -> [(moveType: MoveType, item: MenuItem)] {
			units.enumerated().map { index, unit in
				(unit.type.moveType, offer(unit, index, aux))
			}
		}

		let core = entries(units, aux: false)
		let aux = auxiliary.map { entries($0, aux: true) }
		if auxiliaryOnly {
			guard let aux, !aux.isEmpty else { return nil }
			return Self(items: aux.map(\.item), leftButtons: [.back, .space, .space, .space])
		}
		let categories: [4 of (title: String, icon: SKTexture, moveType: MoveType)] = [
			("Infantry", .shopInfantry, .leg),
			("Trucks", .shopWheels, .wheel),
			("Armor", .shopTracked, .track),
			("Air", .shopAir, .air),
		]

		func menu(showAux: Bool, filter: MenuSlot?) -> Self {
			let offers = showAux ? (aux ?? []) : core
			let moveType = if case .right(let index) = filter { categories[index].moveType } else { nil as MoveType? }
			var items = offers.compactMap { moveType == nil || $0.moveType == moveType ? $0.item : nil }
			if items.isEmpty, aux != nil {
				let status = offers.isEmpty ? "Core unit limit reached" : "No units match this filter"
				items = [.apply(icon: .clear, status: status)]
			}

			let toggle: MenuItem = if aux != nil {
				.init(icon: showAux ? .plus : .HQ, status: .init(
					text: showAux ? "Auxiliary units · Switch to Core" : "Core units · Switch to Aux"
				)) { stack, _ in
					let index = stack.count - 1
					stack[index] = menu(showAux: !showAux, filter: filter)
				}
			} else {
				.space
			}

			return Self(
				items: items,
				leftButtons: [.back, toggle, .space, .space],
				rightButtons: .init { index in
					let category = categories[index]
					return .init(icon: category.icon, status: .init(text: category.title)) { stack, slot in
						let index = stack.count - 1
						stack[index] = menu(showAux: showAux, filter: filter == slot ? nil : slot)
					}
				},
				selectedSideButton: filter
			)
		}

		return menu(showAux: core.isEmpty, filter: nil)
	}
}

extension Unit {

	func purchaseStatus(prestige: UInt16) -> String {
		"\(stats.cost) / \(prestige)\n" + status()
	}
}
