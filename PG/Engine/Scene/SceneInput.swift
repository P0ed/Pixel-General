import SpriteKit

extension Scene where State: ~Copyable {

	func processKeyEvent(_ event: NSEvent) {
		if let nodes, let input = mode.keyboard(nodes, event) {
			apply(input)
		}
		let flags = event.modifierFlags.intersection([.shift, .command])

		switch event.characters {
		case "f" where flags == .command: window.toggleFullScreen(nil)
		case "q" where flags == .command: saveAndExit()
		default: break
		}
	}

	func processMouseEvent(_ event: NSEvent) {
		guard let nodes, let baseNodes else { return }
		if menuState == nil {
			if let input = mode.mouse(nodes, event) {
				apply(input)
			}
		} else {
			guard self.nodes(at: event.location(in: self))
				.contains(where: { n in n == baseNodes.menu })
			else { return apply(.action(.b)) }

			baseNodes.menu.nodes(at: event.location(in: baseNodes.menu))
				.compactMap { n in n as? SKShapeNode }.first
				.flatMap { n in n.name == nil ? n : nil }
				.flatMap(baseNodes.menu.children.firstIndex)
				.map { idx in apply(.tile(XY(idx, 0))) }
		}
	}
}

extension Input {

	init?(keyboardEvent event: NSEvent) {
		let flags = event.modifierFlags.intersection([.shift, .command])

		switch event.keyCode {
		case 36, 49: self = .action(.a)
		case 51: self = .action(.b)
		case 53: self = .menu

		default: switch event.specialKey {
		case .tab: self = .target(flags == .shift ? .prev : .next)
		case .leftArrow: self = .direction(.left)
		case .rightArrow: self = .direction(.right)
		case .downArrow: self = .direction(.down)
		case .upArrow: self = .direction(.up)

		default: switch event.characters {
		case "[": self = .target(.prev)
		case "]": self = .target(.next)
		case "a": self = .action(.a)
		case "s": self = .action(.b)
		case "q": self = .action(.c)
		case "w": self = .action(.d)
		case "z": self = .scale(1)
		case "x": self = .scale(2)
		case "c": self = .scale(4)
		case "§": self = .mode
		default: return nil
		}
		}
		}
	}
}
