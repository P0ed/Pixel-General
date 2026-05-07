import SpriteKit

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

extension StrategicNodes {

	func mouse(_ event: NSEvent) -> Input? {
		nil
//		let location = event.location(in: map.layers[0])
//		return .tile(
//			XY(
//				map.layers[0].tileColumnIndex(fromPosition: location),
//				map.layers[0].tileRowIndex(fromPosition: location)
//			)
//		)
	}
}
