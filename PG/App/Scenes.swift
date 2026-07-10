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
		Scene(mode: .hq, state: HQState(sim: core.hqSim()))
	}

	static var strategic: SKScene {
		let sim = clone(core.strategic!)
		let centroid = sim.centroid(for: sim.human)
		return Scene(
			mode: .strategic,
			state: StrategicState(sim: sim, ui: StrategicUI(cursor: centroid, camera: centroid))
		)
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
