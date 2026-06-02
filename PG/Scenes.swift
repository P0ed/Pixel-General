import SpriteKit
import COR

extension SKScene {

	static var auto: SKScene {
		switch core.location {
		case .hq: .hq
		case .strategic: .strategic
		case .tactical: .tactical
		@unknown default: fatalError()
		}
	}

	static var hq: SKScene {
		Scene(mode: .hq, state: clone(core.hq!))
	}

	static var strategic: SKScene {
		Scene(mode: .strategic, state: clone(core.strategic!))
	}

	static var tactical: SKScene {
		Scene(mode: .tactical, state: clone(core.tactical!))
	}

	static var editor: SKScene {
		Scene(mode: .editor, state: EditorState())
	}
}
