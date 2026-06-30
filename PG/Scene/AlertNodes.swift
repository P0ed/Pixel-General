import SpriteKit

extension BaseNodes {

	static let alertSize = CGSize(width: 320.0, height: 200.0)
	static let alertFieldSize = CGSize(width: 272.0, height: 26.0)
	static let alertButtonSize = CGSize(width: 70.0, height: 30.0)

	private static func wrapWidth(_ panelWidth: CGFloat) -> CGFloat { panelWidth * 2.0 }

	func showAlert(_ alert: Alert) {
		self.alert.removeAllActions()
		self.alert.isHidden = false
		redrawAlert(alert)
		self.alert.setScale(0.01)
		self.alert.run(.scale(to: 1.0, duration: 0.15))
	}

	func hideAlert() {
		alert.removeAllActions()
		alert.run(.scale(to: 0.01, duration: 0.15)) {
			alert.isHidden = true
			alert.removeAllChildren()
		}
	}

	func redrawAlert(_ alert: Alert) {
		self.alert.removeAllChildren()
		addAlertContent(alert)
		updateAlert(alert)
	}

	func updateAlert(_ alert: Alert) {
		guard let field = alert.field,
			let label = self.alert.childNode(withName: "//alertText") as? SKLabelNode,
			let caret = self.alert.childNode(withName: "//alertCaret")
		else { return }

		if field.text.isEmpty {
			label.text = field.placeholder
			label.fontColor = .darkSurface
		} else {
			label.text = field.text
			label.fontColor = .textDefault
		}
		caret.position.x = label.position.x + (field.text.isEmpty ? 0.0 : label.frame.width) + 1.0
	}

	func alertActionIndex(at scenePoint: CGPoint, in scene: SKScene) -> Int? {
		let point = alert.convert(scenePoint, from: scene)
		for node in alert.nodes(at: point) {
			var current: SKNode? = node
			while let n = current {
				if let name = n.name, name.hasPrefix("alertButton"),
					let index = Int(name.dropFirst("alertButton".count)) {
					return index
				}
				current = n.parent
			}
		}
		return nil
	}

	private func addAlertContent(_ alert: Alert) {
		let title = SKLabelNode(size: .m)
		title.text = alert.title
		title.horizontalAlignmentMode = .center
		title.verticalAlignmentMode = .center
		title.position = CGPoint(x: 0.0, y: Self.alertSize.height / 2.0 - 26.0)
		self.alert.addChild(title)

		if !alert.message.isEmpty {
			let message = SKLabelNode(size: .s)
			message.text = alert.message
			message.horizontalAlignmentMode = .center
			message.verticalAlignmentMode = .center
			message.preferredMaxLayoutWidth = Self.wrapWidth(Self.alertSize.width - 40.0)
			message.position = CGPoint(x: 0.0, y: alert.field == nil ? 16.0 : 36.0)
			self.alert.addChild(message)
		}

		if let field = alert.field { addAlertField(field) }

		addAlertButtons(alert.actions)
	}

	private func addAlertField(_ field: Alert.Field) {
		let bg = SKShapeNode(rectOf: Self.alertFieldSize, cornerRadius: 4.0)
		bg.fillColor = .fieldSurface
		bg.strokeColor = .clear
		bg.position = CGPoint(x: 0.0, y: -16.0)
		self.alert.addChild(bg)

		let leftPad = -Self.alertFieldSize.width / 2.0 + 8.0

		let label = SKLabelNode(size: .s, color: .textDefault)
		label.name = "alertText"
		label.horizontalAlignmentMode = .left
		label.verticalAlignmentMode = .center
		label.position = CGPoint(x: leftPad, y: 0.0)
		bg.addChild(label)

		let caret = SKSpriteNode(color: .textDefault, size: CGSize(width: 1.5, height: 9.0))
		caret.name = "alertCaret"
		caret.position = CGPoint(x: leftPad, y: 0.0)
		caret.run(.repeatForever(.sequence([
			.fadeOut(withDuration: 0.4),
			.fadeIn(withDuration: 0.4),
		])))
		bg.addChild(caret)
	}

	private func addAlertButtons(_ actions: [Alert.Action]) {
		let size = Self.alertButtonSize
		let gap = 10.0
		let count = CGFloat(actions.count)
		let total = count * size.width + max(0.0, count - 1.0) * gap
		let startX = -total / 2.0 + size.width / 2.0
		let hints = ["A", "B", "C", "D"]

		for (index, action) in actions.enumerated() {
			let frame = SKShapeNode(rectOf: size, cornerRadius: 4.0)
			frame.name = "alertButton\(index)"
			frame.fillColor = .lightSurface.withAlphaComponent(0.9)
			frame.strokeColor = .clear
			frame.position = CGPoint(
				x: startX + CGFloat(index) * (size.width + gap),
				y: -Self.alertSize.height / 2.0 + 28.0
			)
			self.alert.addChild(frame)

			let label = SKLabelNode(size: .s, color: .textDefault)
			label.text = action.title
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .center
			label.preferredMaxLayoutWidth = Self.wrapWidth(size.width - 8.0)
			frame.addChild(label)

			let hint = SKLabelNode(size: .s, color: .selectedCursor)
			hint.text = hints[index]
			hint.horizontalAlignmentMode = .center
			hint.verticalAlignmentMode = .center
			hint.position = CGPoint(x: 0.0, y: -size.height / 2.0 - 9.0)
			frame.addChild(hint)
		}
	}
}
