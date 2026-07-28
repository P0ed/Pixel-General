import SpriteKit
import COR

extension BaseNodes {

	static let itemSize = CGSize(width: 64.0, height: 64.0)
	static let gridSize = CGSize(width: itemSize.width * 4, height: itemSize.height * 4)
	static let sideSize = CGSize(width: 48.0, height: gridSize.height)
	static let buttonSize = CGSize(width: 24.0, height: 24.0)
	static let buttonIconSize = CGSize(width: 16.0, height: 16.0)
	static let menuSize = CGSize(
		width: gridSize.width + sideSize.width * 2.0,
		height: gridSize.height
	)

	static let itemName = "menuItem"
	static let leftName = "menuLeft"
	static let rightName = "menuRight"
	private static let sideName = "menuSide"

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
		addMenuSide(menuState.leftButtons, name: Self.leftName, sign: -1.0)
		addMenuSide(menuState.rightButtons, name: Self.rightName, sign: 1.0)
	}

	private func addMenuItems<Action>(_ menuState: MenuState<Action>) {
		menuState.items.enumerated().map { idx, item in
			let frame = SKShapeNode(rectOf: Self.itemSize)
			frame.name = "\(Self.itemName)\(idx)"
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

	/// An opaque bezel flanking the grid, carrying four buttons aligned with
	/// the grid rows — `A` topmost, `D` bottommost.
	private func addMenuSide<Action>(_ buttons: [4 of MenuItem<Action>], name: String, sign: CGFloat) {
		let side = SKShapeNode(rectOf: Self.sideSize)
		side.name = Self.sideName
		side.fillColor = .darkGray
		side.strokeColor = .clear
		side.position = CGPoint(
			x: sign * (Self.gridSize.width + Self.sideSize.width) / 2.0,
			y: 0.0
		)
		menu.addChild(side)

		for index in buttons.indices {
			let frame = SKShapeNode(rectOf: Self.buttonSize, cornerRadius: 3.0)
			frame.name = "\(name)\(index)"
			frame.fillColor = .lightSurface.withAlphaComponent(0.15)
			frame.strokeColor = .lightSurface.withAlphaComponent(0.4)
			frame.lineWidth = 1.0
			frame.position = CGPoint(
				x: 0.0,
				y: Self.gridSize.height / 2.0
					- Self.itemSize.height / 2.0
					- CGFloat(index) * Self.itemSize.height
			)
			side.addChild(frame)

			let sprite = SKSpriteNode(texture: SKTexture(image: buttons[index].icon))
			sprite.texture?.filteringMode = .nearest
			sprite.size = Self.buttonIconSize
			frame.addChild(sprite)
		}
	}

	func updateMenu<Action>(_ menuState: MenuState<Action>) {
		for index in menuState.items.indices {
			guard let frame = menu.childNode(withName: "\(Self.itemName)\(index)") as? SKShapeNode
			else { continue }
			frame.fillColor = menuState.cursor == index ? .lightSurface.withAlphaComponent(0.9) : .clear
			frame.isHidden = index / 16 != menuState.cursor / 16
		}
	}

	/// Maps a tap inside the menu onto the input the same control would send
	/// from a keyboard or gamepad: grid cells move/fire the cursor, side
	/// buttons fire as `L`/`R` modified actions.
	func menuInput(at scenePoint: CGPoint, in scene: SKScene) -> Input? {
		let point = menu.convert(scenePoint, from: scene)
		for node in menu.nodes(at: point) {
			var current: SKNode? = node
			while let hit = current {
				if let input = hit.name.flatMap(Input.init(menuNode:)) { return input }
				current = hit.parent
			}
		}
		return nil
	}
}

private extension Input {

	@MainActor
	init?(menuNode name: String) {
		func index(_ prefix: String) -> Int? {
			name.hasPrefix(prefix) ? Int(name.dropFirst(prefix.count)) : nil
		}

		if let idx = index(BaseNodes.itemName) {
			self = .tile(XY(idx, 0))
		} else if let idx = index(BaseNodes.leftName), idx < InputAction.all.count {
			self = .action(InputAction.all[idx], modifiers: .left)
		} else if let idx = index(BaseNodes.rightName), idx < InputAction.all.count {
			self = .action(InputAction.all[idx], modifiers: .right)
		} else {
			return nil
		}
	}
}
