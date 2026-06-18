import SpriteKit

extension BaseNodes {

	func showMenu<Action>(_ menuState: MenuState<Action>) {
		menu.isHidden = false
		addMenuItems(menuState)
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
		addMenuItems(menuState)
		updateMenu(menuState)
	}

	private func addMenuItems<Action>(_ menuState: MenuState<Action>) {
		menuState.items.enumerated().map { idx, item in
			let frame = SKShapeNode(rectOf: Self.itemSize)
			frame.strokeColor = .clear

			let x = CGFloat(idx % menuState.cols) * Self.itemSize.width
			let y = CGFloat(idx % 16 / menuState.cols) * Self.itemSize.height

			frame.position = CGPoint(
				x: Self.itemSize.width / 2.0 - Self.menuSize.width / 2.0 + x,
				y: Self.menuSize.height / 2.0 - Self.itemSize.height / 2.0 - y
			)

			let sprite = SKSpriteNode(texture: SKTexture(image: item.icon))
			sprite.texture?.filteringMode = .nearest
			frame.addChild(sprite)

			return frame
		}
		.forEach(menu.addChild)
	}

	func updateMenu<Action>(_ menuState: MenuState<Action>) {
		menu.children.enumerated().forEach { idx, item in
			if let frame = item as? SKShapeNode, frame.name == nil {
				frame.fillColor = menuState.cursor == idx ? .lightSurface.withAlphaComponent(0.9) : .clear
				frame.isHidden = idx / 16 != menuState.cursor / 16
			}
		}
	}
}
