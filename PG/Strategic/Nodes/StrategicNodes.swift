import SpriteKit

struct StrategicNodes {
	weak var scene: StrategicScene?

	init(scene: StrategicScene) {
		self.scene = scene
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
