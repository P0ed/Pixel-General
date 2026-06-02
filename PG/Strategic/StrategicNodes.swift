import SpriteKit
import COR

@MainActor
struct StrategicNodes {
	weak var scene: StrategicScene?
	var camera: SKCameraNode

	init(scene: StrategicScene) {
		self.scene = scene
		self.camera = Self.addCamera(root: scene)
	}

	private static func addCamera(root: SKNode) -> SKCameraNode {
		let camera = SKCameraNode()
		root.addChild(camera)
		(root as? SKScene)?.camera = camera
		return camera
	}
}

extension StrategicNodes {

	func update(_ state: borrowing StrategicState) {
		
	}
}
