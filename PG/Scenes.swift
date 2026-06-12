import SpriteKit
import COR

extension SKScene {

	static var auto: SKScene {
		switch core.location {
		case .hq: .hq
		case .strategic: .strategic
		case .tactical: .tactical
		}
	}

	static var hq: SKScene {
		Scene(mode: .hq, state: clone(core.hq!))
	}

	static var strategic: SKScene {
		Scene(mode: .strategic, state: clone(core.strategic!))
	}

	static var tactical: SKScene {
		var state = clone(core.tactical!)
		// A peer-relative `.remote` seat is meaningless without a session
		// (e.g. a saved multiplayer battle loaded standalone) — hand it to
		// the AI so the game doesn't stall waiting for the wire.
		if net == nil {
			state.players.modifyEach { _, p in
				if p.type == .remote { p.type = .ai }
			}
		}
		return Scene(mode: .tactical, state: state)
	}

	static var editor: SKScene {
		Scene(mode: .editor, state: EditorState())
	}
}
