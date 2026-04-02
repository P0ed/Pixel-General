import SpriteKit

struct BaseNodes {
	var menu: SKNode
	var status: SKLabelNode
	var action: SKLabelNode
	var icon: SKSpriteNode
}

struct Status {
	var text: String
	var action: Either<String, NSImage>
}

extension Scene where State: ~Copyable {

	func makeBaseNodes() -> BaseNodes {
		BaseNodes(
			menu: addMenu(),
			status: addStatus(),
			action: addStatus(alignment: .right),
			icon: addIcon()
		)
	}

	func addMenu() -> SKNode {
		let menu = SKShapeNode(
			rectOf: BaseNodes.menuSize,
			cornerRadius: BaseNodes.outerR
		)
		menu.fillColor = .lightGray
		menu.strokeColor = .gray
		menu.zPosition = 68.0
		menu.isHidden = true
		camera?.addChild(menu)
		return menu
	}

	func addStatus(alignment: SKLabelHorizontalAlignmentMode = .left) -> SKLabelNode {
		let label = SKLabelNode(size: .s)
		camera?.addChild(label)
		label.zPosition = 67.0
		label.horizontalAlignmentMode = alignment
		label.verticalAlignmentMode = .baseline
		return label
	}

	func addIcon() -> SKSpriteNode {
		let node = SKSpriteNode()
		node.zPosition = 66.0
		node.size = CGSize(width: 24.0, height: 12.0)
		camera?.addChild(node)
		return node
	}
}

extension BaseNodes {

	static let inset = 2.0 as CGFloat
	static let spacing = 2.0 as CGFloat
	static let outerR = 8.0 as CGFloat
	static let innerR = 6.0 as CGFloat

	static let itemSize = CGSize(width: 48.0, height: 36.0)
	static let menuSize = CGSize(
		width: itemSize.width * 4 + spacing * 3 + inset * 2,
		height: itemSize.height * 3 + spacing * 2 + inset * 2
	)

	func layout(size: CGSize) {
		status.position = CGPoint(
			x: Self.inset - size.width / 2.0,
			y: Self.inset - size.height / 2.0
		)
		action.position = CGPoint(
			x: size.width / 2.0 - Self.inset,
			y: Self.inset - size.height / 2.0
		)
		icon.position = CGPoint(
			x: size.width / 2.0 - 18.0,
			y: 12.0 - size.height / 2.0
		)
	}

	func updateStatus(_ data: Status) {
		status.text = data.text
		action.text = data.action.mapA(id)
		icon.texture = data.action.mapB(SKTexture.init(image:))
		icon.texture?.filteringMode = .nearest
	}

	func showMenu<State: ~Copyable>(_ menuState: MenuState<State>) {
		menu.isHidden = false
		addMenuItems(menuState)
		updateMenu(menuState)
	}

	func hideMenu() {
		menu.isHidden = true
		menu.removeAllChildren()
	}

	func redrawMenu<State: ~Copyable>(_ menuState: MenuState<State>) {
		menu.removeAllChildren()
		addMenuItems(menuState)
		updateMenu(menuState)
	}

	private func addMenuItems<State: ~Copyable>(_ menuState: MenuState<State>) {
		menuState.items.enumerated().map { idx, item in
			let frame = SKShapeNode(rectOf: Self.itemSize, cornerRadius: Self.innerR)

			let x = CGFloat(idx % menuState.cols) * (Self.itemSize.width + Self.spacing)
			let y = CGFloat(idx % 12 / menuState.cols) * (Self.itemSize.height + Self.spacing)

			frame.position = CGPoint(
				x: Self.inset + Self.itemSize.width / 2.0 - Self.menuSize.width / 2.0 + x,
				y: Self.menuSize.height / 2.0 - Self.inset - Self.itemSize.height / 2.0 - y
			)

			let sprite = SKSpriteNode(imageNamed: item.icon)
			sprite.texture?.filteringMode = .nearest
			frame.addChild(sprite)

			return frame
		}
		.forEach(menu.addChild)
	}

	func updateMenu<State: ~Copyable>(_ menuState: MenuState<State>) {
		menu.children.enumerated().forEach { idx, item in
			if let frame = item as? SKShapeNode, frame.name == nil {
				frame.fillColor = menuState.cursor == idx ? .gray : .darkGray
				frame.strokeColor = menuState.cursor == idx ? .gray : .darkGray
				frame.isHidden = idx / 12 != menuState.cursor / 12
			}
		}
	}
}
