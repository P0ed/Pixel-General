import SpriteKit

@MainActor
struct BaseNodes {
	var menu: SKNode
	var status: SKLabelNode
	var action: SKLabelNode
	var icon: SKSpriteNode
}

struct Status {
	var text: String = ""
	var action: String = ""
	var flag: NSImage?
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
		let menu = SKShapeNode(rectOf: BaseNodes.menuSize)
		menu.fillColor = .darkGray.withAlphaComponent(0.9)
		menu.strokeColor = .clear
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

	static let itemSize = CGSize(width: 64.0, height: 64.0)
	static let menuSize = CGSize(width: itemSize.width * 4, height: itemSize.height * 4)

	func layout(size: CGSize) {
		let inset = 4.0 as CGFloat
		status.position = CGPoint(
			x: inset - size.width / 2.0,
			y: inset - size.height / 2.0
		)
		action.position = CGPoint(
			x: size.width / 2.0 - inset,
			y: inset - size.height / 2.0
		)
		icon.position = CGPoint(
			x: size.width / 2.0 - 18.0,
			y: 12.0 - size.height / 2.0
		)
	}

	func updateStatus(_ data: Status) {
		status.text = data.text
		action.text = data.action
		icon.texture = data.flag.map(SKTexture.init(image:))
		icon.texture?.filteringMode = .nearest
	}
}
