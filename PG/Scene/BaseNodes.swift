import SpriteKit
import UIKit

@MainActor
struct BaseNodes {
	var menu: MenuNodes
	var status: SKLabelNode
	var icon: SKSpriteNode
}

struct Status {
	var text: String = ""
	var flag: SKTexture?
}

extension Scene where State: ~Copyable {

	func makeBaseNodes() -> BaseNodes {
		BaseNodes(
			menu: addMenu(),
			status: addStatus(),
			icon: addIcon()
		)
	}

	func addMenu() -> MenuNodes {
		let menu = MenuNodes.make()
		camera?.addChild(menu.root)
		return menu
	}

	func addStatus() -> SKLabelNode {
		let label = SKLabelNode()
		label.fontName = "Menlo"
		label.fontSize = 14.0
		label.fontColor = .white
		label.setScale(0.5)
		label.numberOfLines = 0
		camera?.addChild(label)
		label.zPosition = 67.0
		label.horizontalAlignmentMode = .left
		label.verticalAlignmentMode = .bottom
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

	func layout(size: CGSize) {
		let inset = 4.0 as CGFloat
		status.position = CGPoint(
			x: inset - size.width / 2.0,
			y: inset - size.height / 2.0
		)
		icon.position = CGPoint(
			x: size.width / 2.0 - 20.0,
			y: size.height / 2.0 - 12.0
		)
	}

	func updateStatus(_ data: Status) {
		status.attributedText = text(data.text)
		icon.texture = data.flag
	}
}

private func text(_ string: String) -> NSAttributedString {
	let s = NSMutableParagraphStyle()
	s.lineSpacing = 4.0
	return NSAttributedString(string: string, attributes: [
		.paragraphStyle: s,
		.font: UIFont(name: "Menlo", size: 14.0)!,
		.foregroundColor: UIColor.white
	])
}
