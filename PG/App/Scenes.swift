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
		Scene(mode: .hq, state: HQState(sim: clone(core.hq)))
	}

	static var strategic: SKScene {
		Scene(mode: .strategic, state: StrategicState(sim: clone(core.strategic!)))
	}

	static var tactical: SKScene {
		var state = TacticalState(sim: clone(core.tactical!))
		if net == nil {
			state.sim.players.modifyEach { _, p in
				if p.type == .remote { p.type = .ai }
			}
		}
		return Scene(mode: .tactical, state: state)
	}

	static var editor: SKScene {
		Scene(mode: .editor, state: EditorState())
	}
}
