import SpriteKit
import COR

extension SKScene {

	static var tactical: TACScene {
		TACScene(state: TacticalState(sim: clone(core.tactical)))
	}
}
