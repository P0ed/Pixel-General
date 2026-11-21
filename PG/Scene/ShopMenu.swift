import COR
import SpriteKit

extension MenuState {

	static func shop(units: [Unit], prestige: UInt16, purchase: (Int) -> Action) -> Self? {
		guard !units.isEmpty else { return nil }

		let entries = units.enumerated().map { index, unit in
			let item = MenuItem<Action>.close(
				icon: unit.image,
				status: .init(text: "\(unit.stats.cost) / \(prestige)\n" + unit.status()),
				action: purchase(index)
			)
			return (moveType: unit.type.moveType, item: item)
		}

		func button(_ title: String, icon: SKTexture, moveType: MoveType) -> MenuItem<Action> {
			.init(icon: icon, status: .init(text: title)) { stack, slot in
				let index = stack.count - 1
				let selection = stack[index].selectedSideButton == slot ? nil : slot
				stack[index].selectedSideButton = selection
				stack[index].items = entries.compactMap { entry in
					selection == nil || entry.moveType == moveType ? entry.item : nil
				}
				stack[index].cursor = 0
			}
		}

		return Self(
			items: entries.map(\.item),
			leftButtons: [.back, .space, .space, .space],
			rightButtons: [
				button("Infantry", icon: .shopInfantry, moveType: .leg),
				button("Trucks", icon: .shopWheels, moveType: .wheel),
				button("Armor", icon: .shopTracked, moveType: .track),
				button("Air", icon: .shopAir, moveType: .air),
			]
		)
	}
}
