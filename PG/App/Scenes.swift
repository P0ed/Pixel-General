import SpriteKit
import COR

extension SKScene {

	static var tactical: TacticalScene {
		TacticalScene(mode: .tactical, state: TacticalState(sim: clone(core.tactical)))
	}
}
