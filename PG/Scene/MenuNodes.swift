import SpriteKit
import COR

struct MenuNodes {
	var root: SKNode
	var items: [16 of MenuSlotNode]
	var left: [4 of MenuSlotNode]
	var right: [4 of MenuSlotNode]
}

extension BaseNodes {
	private static let showMenuActionKey = "menu.show"
	private static let hideMenuActionKey = "menu.hide"

	static let itemSize = CGSize(width: 64.0, height: 64.0)
	static let gridSize = CGSize(width: itemSize.width * 4, height: itemSize.height * 4)
	static let buttonSize = CGSize(width: 28.0, height: 30.0)
	static let buttonIconSize = CGSize(width: 24.0, height: 24.0)
	static let buttonTravel = 2.0 as CGFloat
	static let side = 64.0 as CGFloat
	static let bezel = 4.0 as CGFloat
	static let depth = 8.0 as CGFloat

	static let menuSize = CGSize(
		width: gridSize.width + side * 2.0,
		height: gridSize.height + bezel * 2.0 + depth
	)

	func showMenu<Action>(_ menuState: MenuState<Action>) {
		let wasHidden = menu.isHidden
		menu.removeAction(forKey: Self.hideMenuActionKey)
		menu.removeAction(forKey: Self.showMenuActionKey)
		menu.isHidden = false
		menu.removeAllChildren()
		addMenuNodes(menuState)
		updateMenu(menuState)
		if wasHidden { menu.position.y = hiddenMenuY }
		menu.run(.moveTo(y: 0.0, duration: 0.22), withKey: Self.showMenuActionKey)
	}

	func hideMenu() {
		menu.removeAction(forKey: Self.showMenuActionKey)
		menu.run(
			.sequence([
				.moveTo(y: hiddenMenuY, duration: 0.22),
				.run {
					menu.isHidden = true
					menu.removeAllChildren()
				},
			]),
			withKey: Self.hideMenuActionKey
		)
	}

	var menuIsHiding: Bool { menu.action(forKey: Self.hideMenuActionKey) != nil }

	private var hiddenMenuY: CGFloat {
		((menu.scene?.size.height ?? CGSize.scene.height) + Self.menuSize.height) / 2.0
	}

	func redrawMenu<Action>(_ menuState: MenuState<Action>) {
		menu.removeAllChildren()
		addMenuNodes(menuState)
		updateMenu(menuState)
	}

	private func addMenuNodes<Action>(_ menuState: MenuState<Action>) {
		addMenuItems(menuState)
		addMenuSide(menuState.leftButtons, slot: MenuSlot.left, sign: -1.0)
		addMenuSide(menuState.rightButtons, slot: MenuSlot.right, sign: 1.0)
	}

	private func addMenuItems<Action>(_ menuState: MenuState<Action>) {
		menuState.items.enumerated().map { idx, item in
			let frame = MenuSlotNode(image: .clear)
			frame.size = Self.itemSize
			frame.slot = .item(idx)
			frame.zPosition = 1.0

			let x = CGFloat(idx % 4) * Self.itemSize.width
			let y = CGFloat(idx % 16 / 4) * Self.itemSize.height

			frame.position = CGPoint(
				x: Self.itemSize.width / 2.0 - Self.gridSize.width / 2.0 + x,
				y: (Self.gridSize.height - Self.itemSize.height + Self.depth) / 2.0 - y
			)

			let icon = SKSpriteNode(image: item.icon)
			icon.zPosition = 1.0
			frame.icon = icon
			frame.addChild(icon)

			return frame
		}
		.forEach(menu.addChild)
	}

	private func addMenuSide<Action>(
		_ buttons: [4 of MenuItem<Action>],
		slot: (Int) -> MenuSlot,
		sign: CGFloat
	) {
		for index in buttons.indices {
			let frame = MenuSlotNode(image: .BTN_0)
			frame.size = Self.buttonSize
			frame.slot = slot(index)
			frame.zPosition = 1.0
			frame.position = CGPoint(
				x: sign * (Self.gridSize.width + Self.side) / 2.0,
				y: Self.buttonY(index)
			)
			menu.addChild(frame)

			let icon = SKSpriteNode(image: buttons[index].icon)
			icon.size = Self.buttonIconSize
			icon.zPosition = 2.0
			icon.position.y = Self.buttonTravel / 2.0
			frame.icon = icon
			frame.addChild(icon)
		}
	}

	private static func buttonY(_ index: Int) -> CGFloat {
		gridSize.height / 2.0
			- itemSize.height / 2.0
			- CGFloat(index) * itemSize.height
			- buttonTravel
	}

	func setMenuButton(_ slot: MenuSlot, pressed: Bool) {
		guard slot.modifier != nil, let frame = sideButton(slot) else { return }
		frame.setImage(pressed ? .BTN_1 : .BTN_0)
		frame.icon?.position.y = Self.buttonTravel / 2.0 * (pressed ? -1.0 : 1.0)
	}

	private func sideButton(_ slot: MenuSlot) -> MenuSlotNode? {
		menu.children
			.first { node in (node as? MenuSlotNode)?.slot == slot } as? MenuSlotNode
	}

	func updateMenu<Action>(_ menuState: MenuState<Action>) {
		for case let frame as MenuSlotNode in menu.children {
			if case .item(let index) = frame.slot {
				frame.isHidden = index / 16 != menuState.cursor / 16
				frame.setImage(menuState.cursor == index ? .highlighted : .clear)
			}
		}
	}

	func menuSlot(at scenePoint: CGPoint, in scene: SKScene) -> MenuSlot? {
		let point = menu.convert(scenePoint, from: scene)
		for node in menu.nodes(at: point) {
			var current: SKNode? = node
			while let hit = current {
				if let frame = hit as? MenuSlotNode { return frame.slot }
				current = hit.parent
			}
		}
		return nil
	}
}

final class MenuSlotNode: SKSpriteNode {
	var slot: MenuSlot = .item(0)
	var icon: SKSpriteNode?
}

extension Input {

	@MainActor
	var menuSlot: MenuSlot? {
		guard case .action(let button?, let modifiers) = self else { return nil }
		if modifiers == .left { return .left(button.index) }
		if modifiers == .right { return .right(button.index) }
		return nil
	}

	@MainActor
	init(slot: MenuSlot) {
		guard let modifier = slot.modifier else {
			self = .tile(XY(slot.index, 0))
			return
		}
		self = .action(InputAction.all[slot.index], modifiers: modifier)
	}
}
