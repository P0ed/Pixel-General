import SpriteKit
import COR

extension SKScene {

	static var tactical: Scene {
		Scene(state: TacticalState(sim: clone(core.tactical)))
	}
}
