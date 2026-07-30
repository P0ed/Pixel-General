import SpriteKit
import COR

@MainActor
struct MenuNodes {
	var root: SKNode
	var items: [16 of MenuSlotNode]
	var left: [4 of MenuSlotNode]
	var right: [4 of MenuSlotNode]
}

extension MenuNodes {

	static func make() -> MenuNodes {
		let image = UIImage.menu
		let root = SKSpriteNode(image: image)
		root.size = BaseNodes.menuSize

		let insets = image.capInsets
		root.centerRect = CGRect(
			x: insets.left / image.size.width,
			y: insets.bottom / image.size.height,
			width: (image.size.width - insets.left - insets.right) / image.size.width,
			height: (image.size.height - insets.top - insets.bottom) / image.size.height
		)
		root.zPosition = 68.0
		root.isHidden = true

		let items = [16 of MenuSlotNode] { index in
			let frame = MenuSlotNode(image: .clear)
			frame.size = BaseNodes.itemSize
			frame.slot = .item(index)
			frame.zPosition = 1.0

			let x = CGFloat(index % 4) * BaseNodes.itemSize.width
			let y = CGFloat(index / 4) * BaseNodes.itemSize.height
			frame.position = CGPoint(
				x: BaseNodes.itemSize.width / 2.0 - BaseNodes.gridSize.width / 2.0 + x,
				y: (BaseNodes.gridSize.height - BaseNodes.itemSize.height + BaseNodes.depth) / 2.0 - y
			)

			let icon = SKSpriteNode(image: nil)
			icon.zPosition = 1.0
			frame.icon = icon
			frame.addChild(icon)
			root.addChild(frame)
			return frame
		}

		func makeSide(slot: (Int) -> MenuSlot, sign: CGFloat) -> [4 of MenuSlotNode] {
			[4 of MenuSlotNode] { index in
				let frame = MenuSlotNode(image: .BTN_0)
				frame.size = BaseNodes.buttonSize
				frame.slot = slot(index)
				frame.zPosition = 1.0
				frame.position = CGPoint(
					x: sign * (BaseNodes.gridSize.width + BaseNodes.side) / 2.0,
					y: BaseNodes.gridSize.height / 2.0
					- BaseNodes.itemSize.height / 2.0
					- CGFloat(index) * BaseNodes.itemSize.height
					+ BaseNodes.buttonTravel * 1.5
				)

				let icon = SKSpriteNode(image: nil)
				icon.size = BaseNodes.buttonIconSize
				icon.zPosition = 2.0
				icon.position.y = BaseNodes.buttonTravel / 2.0
				frame.icon = icon
				frame.addChild(icon)
				root.addChild(frame)
				return frame
			}
		}

		return MenuNodes(
			root: root,
			items: items,
			left: makeSide(slot: MenuSlot.left, sign: -1.0),
			right: makeSide(slot: MenuSlot.right, sign: 1.0)
		)
	}
}

extension BaseNodes {
	private static let showMenuActionKey = "menu.show"
	private static let hideMenuActionKey = "menu.hide"

	fileprivate static let itemSize = CGSize(width: 64.0, height: 64.0)
	fileprivate static let gridSize = CGSize(width: itemSize.width * 4, height: itemSize.height * 4)
	fileprivate static let buttonSize = CGSize(width: 28.0, height: 30.0)
	fileprivate static let buttonIconSize = CGSize(width: 24.0, height: 24.0)
	fileprivate static let buttonTravel = 2.0 as CGFloat
	fileprivate static let side = 64.0 as CGFloat
	static let bezel = 4.0 as CGFloat
	fileprivate static let depth = 8.0 as CGFloat

	static let menuSize = CGSize(
		width: gridSize.width + side * 2.0,
		height: gridSize.height + bezel * 2.0 + depth
	)

	func showMenu<Action>(_ menuState: MenuState<Action>) {
		let wasHidden = menu.root.isHidden
		menu.root.removeAction(forKey: Self.hideMenuActionKey)
		menu.root.removeAction(forKey: Self.showMenuActionKey)
		menu.root.isHidden = false
		updateMenu(menuState)
		if wasHidden { menu.root.position.y = hiddenMenuY }
		menu.root.run(.moveTo(y: 0.0, duration: 0.22), withKey: Self.showMenuActionKey)
	}

	func hideMenu() {
		menu.root.removeAction(forKey: Self.showMenuActionKey)
		menu.root.run(
			.sequence([
				.moveTo(y: hiddenMenuY, duration: 0.22),
				.run {
					menu.root.isHidden = true
				},
			]),
			withKey: Self.hideMenuActionKey
		)
	}

	var menuIsHiding: Bool { menu.root.action(forKey: Self.hideMenuActionKey) != nil }

	private var hiddenMenuY: CGFloat {
		((menu.root.scene?.size.height ?? CGSize.scene.height) + Self.menuSize.height) / 2.0
	}

	func redrawMenu<Action>(_ menuState: MenuState<Action>) {
		updateMenu(menuState)
	}

	fileprivate static func buttonY(_ index: Int) -> CGFloat {
		gridSize.height / 2.0
			- itemSize.height / 2.0
			- CGFloat(index) * itemSize.height
	}

	func setMenuButton(_ slot: MenuSlot, pressed: Bool) {
		guard let frame = sideButton(slot) else { return }
		frame.setImage(pressed ? .BTN_1 : .BTN_0)
		frame.icon?.position.y = Self.buttonTravel / 2.0 * (pressed ? -1.0 : 1.0)
	}

	private func sideButton(_ slot: MenuSlot) -> MenuSlotNode? {
		switch slot {
		case .left(let index) where (0 ..< 4).contains(index): menu.left[index]
		case .right(let index) where (0 ..< 4).contains(index): menu.right[index]
		case .left, .right: nil
		case .item: nil
		}
	}

	func updateMenu<Action>(_ menuState: MenuState<Action>) {
		let pageStart = menuState.cursor / 16 * 16
		for offset in 0 ..< 16 {
			let frame = menu.items[offset]
			let index = pageStart + offset
			frame.slot = .item(index)
			frame.isHidden = index >= menuState.items.count
			frame.setImage(menuState.cursor == index ? .highlighted : .clear)
			let image = index < menuState.items.count ? menuState.items[index].icon : nil
			frame.icon?.setImage(image)
			frame.icon?.size = image?.size ?? .zero
		}
		for index in 0 ..< 4 {
			menu.left[index].icon?.setImage(menuState.leftButtons[index].icon)
			menu.right[index].icon?.setImage(menuState.rightButtons[index].icon)
		}
	}

	func menuSlot(at scenePoint: CGPoint, in scene: SKScene) -> MenuSlot? {
		let point = menu.root.convert(scenePoint, from: scene)
		for node in menu.root.nodes(at: point) {
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
