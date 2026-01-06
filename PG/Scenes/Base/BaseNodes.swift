import SpriteKit

struct BaseNodes {
	var menu: SKNode
	var status: SKLabelNode
	var global: SKLabelNode
}

extension Scene where State: ~Copyable {

	func makeBaseNodes() -> BaseNodes {
		BaseNodes(
			menu: addMenu(),
			status: addStatus(),
			global: addStatus(alignment: .right),
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
		menu.setScale(0.5)
		camera?.addChild(menu)
		return menu
	}

	func addStatus(alignment: SKLabelHorizontalAlignmentMode = .left) -> SKLabelNode {
		let label = SKLabelNode(size: .s)
		camera?.addChild(label)
		label.zPosition = 66.0
		label.horizontalAlignmentMode = alignment
		label.verticalAlignmentMode = .baseline
		return label
	}
}

extension BaseNodes {

	static let inset = 8.0 as CGFloat
	static let spacing = 8.0 as CGFloat
	static let outerR = 12.0 as CGFloat
	static let innerR = outerR - inset / 2.0 as CGFloat

	static let itemSize = CGSize(width: 64.0, height: 48.0)
	static let inspectorSize = CGSize(
		width: itemSize.width * 2 + spacing,
		height: itemSize.height * 3 + spacing * 2
	)
	static let menuSize = CGSize(
		width: itemSize.width * 5 + spacing * 4 + inset * 2,
		height: itemSize.height * 3 + spacing * 2 + inset * 2
	)

	func layout(size: CGSize) {
		status.position = CGPoint(
			x: Self.inset - size.width / 2.0,
			y: Self.inset - size.height / 2.0
		)
		global.position = CGPoint(
			x: size.width / 2.0 - Self.inset,
			y: Self.inset - size.height / 2.0
		)
	}

	func showMenu<State: ~Copyable>(_ menuState: MenuState<State>) {
		menu.isHidden = false
		addMenuItems(menuState)
		if menuState.layout == .inspector { addMenuInspector() }
		updateMenu(menuState)
	}

	func hideMenu() {
		menu.isHidden = true
		menu.removeAllChildren()
	}

	private func addMenuItems<State: ~Copyable>(_ menuState: MenuState<State>) {
		menuState.items.enumerated().map { idx, item in
			let frame = SKShapeNode(rectOf: Self.itemSize, cornerRadius: Self.innerR)

			let x = CGFloat(idx % menuState.cols) * (Self.itemSize.width + Self.spacing)
			let y = CGFloat(idx / menuState.cols) * (Self.itemSize.height + Self.spacing)

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

	func addMenuInspector() {
		let frame = SKShapeNode(rectOf: Self.inspectorSize, cornerRadius: Self.innerR)
		frame.fillColor = .gray
		frame.strokeColor = .darkGray
		frame.name = "inspector"
		frame.position = CGPoint(
			x: Self.menuSize.width / 2.0 - Self.inset - Self.inspectorSize.width / 2.0,
			y: Self.menuSize.height / 2.0 - Self.inset - Self.inspectorSize.height / 2.0
		)
		menu.addChild(frame)

		let label = SKLabelNode(size: .l)
		label.verticalAlignmentMode = .top
		label.horizontalAlignmentMode = .left
		label.position = CGPoint(
			x: Self.inset - Self.inspectorSize.width / 2.0,
			y: Self.inspectorSize.height / 2.0 - Self.inset,
		)
		label.zPosition = 0.1
		label.name = "label"
		frame.addChild(label)
	}

	func updateMenu<State: ~Copyable>(_ menuState: MenuState<State>) {
		menu.children.enumerated().forEach { idx, item in
			if let frame = item as? SKShapeNode, frame.name == nil {
				frame.fillColor = menuState.cursor == idx ? .gray : .darkGray
				frame.strokeColor = menuState.cursor == idx ? .darkGray : .black
			}
			if idx == menuState.cursor, let inspector = menu.menuInspectorLabel {
				inspector.text = menuState.items[idx].description
			}
		}
	}
}

extension SKNode {

	var menuInspectorLabel: SKLabelNode? {
		childNode(withName: "inspector")?.childNode(withName: "label") as? SKLabelNode
	}
}
