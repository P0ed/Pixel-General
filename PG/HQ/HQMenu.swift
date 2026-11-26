import SpriteKit
import COR

@MainActor
final class HQMenu {
	typealias Menu = MenuState<Action>
	typealias Item = MenuItem<Action>

	private(set) var hq = clone(core.hq)

	private func newGameMenu() -> Menu {
		Menu(
			items: Country.playable.map { country in
				.close(icon: country.flag, status: "\(country)") {
					core = .new(country: country)
					core.save()
					view.present(.tactical)
				}
			},
			leftButtons: [.back, .space, .space, .space]
		)
	}

	func menu(cursor: Int = 0) -> Menu {
		Menu(
			items: hq.units.indices.map { slot in
				let unit = hq.units[slot]
				let text = unit.alive ? unit.status() : "Purchase unit"
				let status = Status(text: "Prestige: \(hq.player.prestige)\n" + text)
				return Item(icon: unit.alive ? unit.image : .plus, status: status) { [self] stack, _ in
					if unit.alive {
						stack.append(unitMenu(slot))
					} else if let shop = shopMenu(slot) {
						stack.append(shop)
					}
				}
			},
			leftButtons: [
				.back,
				.push(icon: .plus, status: "New game", menu: newGameMenu),
				.load { core.save() },
				.prefs,
			],
			rightButtons: [
				.push(icon: .arrowRight, status: "New scenario", menu: scenarioMenu),
				.space, .space, .space,
			],
			cursor: cursor
		)
	}

	private func unitMenu(_ slot: Int) -> Menu {
		let unit = hq.units[slot]
		let upgrades = Shop(country: hq.country, tier: hq.player.tier).upgrades(for: unit)
		var items: [Item] = [
			.push(icon: .arrowRight, status: "Move or swap \(unit.typeDescription)") {
				self.moveMenu(slot)
			}
		]
		if !upgrades.isEmpty {
			items.append(.push(icon: .arrowUp, status: "Upgrade \(unit.typeDescription)") {
				let offers = upgrades.map { option in
					let result = unit.upgraded(to: option.model)
					let cost = unit.upgradeCost(to: option.model)
					return self.order(
						.upgrade(slot, option.model), icon: result.image,
						status: "\(cost) / \(self.hq.player.prestige)\n" + result.status(),
						cursor: slot
					)
				}
				return Menu(items: offers, leftButtons: [.back, .space, .space, .space])
			})
		}
		items.append(order(
			.sell(slot), icon: .minus, status: "Sell \(unit.typeDescription) for \(unit.stats.cost / 2)",
			cursor: slot
		))
		return Menu(items: items, leftButtons: [.back, .space, .space, .space])
	}

	private func moveMenu(_ slot: Int) -> Menu {
		let destinations = hq.units.indices.map { dest in
			let other = hq.units[dest]
			return order(
				.swap(slot, dest), icon: other.alive ? other.image : .plus,
				status: "Slot \(dest + 1) · " + (other.alive ? other.typeDescription : "Empty"),
				cursor: dest
			)
		}
		return Menu(items: destinations, leftButtons: [.back, .space, .space, .space], cursor: slot)
	}

	private func shopMenu(_ slot: Int) -> Menu? {
		.shop(units: hq.shop) { unit, index, _ in
			order(
				.purchase(index, slot), icon: unit.image, status: unit.purchaseStatus(prestige: hq.player.prestige),
				cursor: slot
			)
		}
	}

	private func order(_ action: HQAction, icon: SKTexture, status: String, cursor: Int) -> Item {
		Item(icon: icon, status: Status(text: status)) { [self] stack, _ in
			guard !hq.reduce(action).isEmpty else { return }
			core.store(hq)
			core.save()
			stack = [menu(cursor: cursor)]
		}
	}
}
