import SpriteKit
import COR

extension SKScene {

	static var auto: SKScene {
		core.tactical == nil ? .hq : .tactical
	}

	static var hq: SKScene {
		Scene(mode: .hq, state: HQState(sim: clone(core.hq)))
	}

	static var tactical: SKScene {
		Scene(mode: .tactical, state: TacticalState(sim: clone(core.tactical!)))
	}
}
