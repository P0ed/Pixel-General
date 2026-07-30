import SpriteKit
import COR

extension BaseNodes {

	static let itemSize = CGSize(width: 64.0, height: 64.0)
	static let gridSize = CGSize(width: itemSize.width * 4, height: itemSize.height * 4)
	static let sideSize = CGSize(width: 48.0, height: gridSize.height)
	static let buttonSize = CGSize(width: 24.0, height: 24.0)
	static let buttonIconSize = CGSize(width: 16.0, height: 16.0)
	static let buttonTravel = 2.0 as CGFloat
	static let menuSize = CGSize(
		width: gridSize.width + sideSize.width * 2.0,
		height: gridSize.height
	)

	func showMenu<Action>(_ menuState: MenuState<Action>) {
		menu.isHidden = false
		addMenuNodes(menuState)
		updateMenu(menuState)
		menu.setScale(0.01)
		menu.run(.scale(to: 1.0, duration: 0.15))
	}

	func hideMenu() {
		menu.run(.scale(to: 0.01, duration: 0.15)) {
			menu.isHidden = true
			menu.removeAllChildren()
		}
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
			let frame = MenuSlotNode(rectOf: Self.itemSize)
			frame.slot = .item(idx)
			frame.strokeColor = .clear

			let x = CGFloat(idx % menuState.cols) * Self.itemSize.width
			let y = CGFloat(idx % 16 / menuState.cols) * Self.itemSize.height

			frame.position = CGPoint(
				x: Self.itemSize.width / 2.0 - Self.gridSize.width / 2.0 + x,
				y: Self.gridSize.height / 2.0 - Self.itemSize.height / 2.0 - y
			)

			let sprite = SKSpriteNode(texture: SKTexture(image: item.icon))
			sprite.texture?.filteringMode = .nearest
			frame.addChild(sprite)

			return frame
		}
		.forEach(menu.addChild)
	}

	private func addMenuSide<Action>(
		_ buttons: [4 of MenuItem<Action>],
		slot: (Int) -> MenuSlot,
		sign: CGFloat
	) {
		let side = SKShapeNode(rectOf: Self.sideSize)
		side.fillColor = .darkGray
		side.strokeColor = .clear
		side.position = CGPoint(
			x: sign * (Self.gridSize.width + Self.sideSize.width) / 2.0,
			y: 0.0
		)
		menu.addChild(side)

		for index in buttons.indices {
			let frame = MenuSlotNode(rectOf: Self.buttonSize, cornerRadius: 3.0)
			frame.slot = slot(index)
			frame.fillColor = .lightSurface.withAlphaComponent(0.15)
			frame.strokeColor = .lightSurface.withAlphaComponent(0.4)
			frame.lineWidth = 1.0
			frame.position = CGPoint(x: 0.0, y: Self.buttonY(index))
			side.addChild(frame)

			let sprite = SKSpriteNode(texture: SKTexture(image: buttons[index].icon))
			sprite.texture?.filteringMode = .nearest
			sprite.size = Self.buttonIconSize
			frame.addChild(sprite)
		}
	}

	private static func buttonY(_ index: Int) -> CGFloat {
		gridSize.height / 2.0
			- itemSize.height / 2.0
			- CGFloat(index) * itemSize.height
	}

	func setMenuButton(_ slot: MenuSlot, pressed: Bool) {
		guard slot.modifier != nil, let frame = sideButton(slot) else { return }
		frame.fillColor = .lightSurface.withAlphaComponent(pressed ? 0.5 : 0.15)
		frame.strokeColor = .lightSurface.withAlphaComponent(pressed ? 0.9 : 0.4)
		frame.position.y = Self.buttonY(slot.index) - (pressed ? Self.buttonTravel : 0.0)
	}

	private func sideButton(_ slot: MenuSlot) -> MenuSlotNode? {
		menu.children
			.lazy
			.flatMap(\.children)
			.first { node in (node as? MenuSlotNode)?.slot == slot } as? MenuSlotNode
	}

	func updateMenu<Action>(_ menuState: MenuState<Action>) {
		for case let frame as MenuSlotNode in menu.children {
			let index = frame.slot.index
			frame.fillColor = menuState.cursor == index ? .lightSurface.withAlphaComponent(0.9) : .clear
			frame.isHidden = index / 16 != menuState.cursor / 16
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

final class MenuSlotNode: SKShapeNode {
	var slot: MenuSlot = .item(0)
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
