import SpriteKit

extension Scene where State: ~Copyable {

	func processKeyEvent(_ event: NSEvent) {
		let flags = event.modifierFlags.intersection([.shift, .command])

		switch event.keyCode {
		case 36, 49: apply(.action(.a))
		case 51: apply(.action(.b))
		case 53: apply(.menu)
		default: break
		}
		switch event.specialKey {
		case .tab: apply(.target(flags == .shift ? .prev : .next))
		case .leftArrow: apply(.direction(.left))
		case .rightArrow: apply(.direction(.right))
		case .downArrow: apply(.direction(.down))
		case .upArrow: apply(.direction(.up))
		default: break
		}
		switch event.characters {
		case "f" where flags == .command: view?.window?.toggleFullScreen(nil)
		case "q" where flags == .command: saveAndExit()
		case "[": apply(.target(.prev))
		case "]": apply(.target(.next))
		case "a": apply(.action(.a))
		case "s": apply(.action(.b))
		case "q": apply(.action(.c))
		case "w": apply(.action(.d))
		case "z": apply(.scale(1.0))
		case "x": apply(.scale(2.0))
		case "c": apply(.scale(4.0))
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
