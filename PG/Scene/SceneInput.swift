import SpriteKit
import UIKit
import COR

extension Scene where State: ~Copyable {

	@discardableResult
	func handle(key: UIKey) -> Bool {
		if alertState?.field != nil { return editAlertField(key) }
		guard let nodes, let input = mode.keyboard(nodes, key) else { return false }
		apply(input)
		return true
	}

	func processTouch(at scenePoint: CGPoint) {
		guard let nodes, let baseNodes else { return }
		if alertState != nil {
			let buttons: [Input] = [.action(.a), .action(.b), .action(.c), .action(.d)]
			baseNodes.alertActionIndex(at: scenePoint, in: self).map { apply(buttons[$0]) }
			return
		}
		if menuState == nil {
			if let input = mode.mouse(nodes, scenePoint) {
				apply(input)
			}
		} else {
			guard self.nodes(at: scenePoint)
				.contains(where: { n in n == baseNodes.menu })
			else { return apply(.action(.b)) }

			baseNodes.menu.nodes(at: baseNodes.menu.convert(scenePoint, from: self))
				.compactMap { n in n as? SKShapeNode }.first
				.flatMap { n in n.name == nil ? n : nil }
				.flatMap(baseNodes.menu.children.firstIndex)
				.map { idx in apply(.tile(XY(idx, 0))) }
		}
	}
}

extension Input {

	@MainActor
	init?(key: UIKey) {
		let shift = key.modifierFlags.contains(.shift)

		switch key.keyCode {
		case .keyboardReturnOrEnter, .keyboardSpacebar: self = .action(.a)
		case .keyboardDeleteOrBackspace: self = .action(.b)
		case .keyboardEscape: self = .menu
		case .keyboardTab: self = .target(shift ? .prev : .next)
		case .keyboardLeftArrow: self = .direction(.left)
		case .keyboardRightArrow: self = .direction(.right)
		case .keyboardDownArrow: self = .direction(.down)
		case .keyboardUpArrow: self = .direction(.up)

		default: switch key.charactersIgnoringModifiers {
		case "1": self = .action(.a, modifiers: .right)
		case "2": self = .action(.b, modifiers: .right)
		case "3": self = .action(.c, modifiers: .right)
		case "4": self = .action(.d, modifiers: .right)
		case "[": self = .target(.prev)
		case "]": self = .target(.next)
		case "a": self = .action(.a)
		case "s": self = .action(.b)
		case "q": self = .action(.c)
		case "w": self = .action(.d)
		case "z": self = .scale(1)
		case "x": self = .scale(2)
		case "c": self = .scale(4)
		default: return nil
		}
		}
	}
}
