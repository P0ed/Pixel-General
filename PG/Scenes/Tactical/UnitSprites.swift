import SpriteKit

extension Unit {

	var hqSprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(imageNamed: imageName)
		sprite.zPosition = 0.2
		sprite.texture?.filteringMode = .nearest
		node.addChild(sprite)

		return node
	}

	var sprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(imageNamed: imageName)
		sprite.zPosition = 0.2
		sprite.xScale = country.team == .axis ? 1.0 : -1.0
		sprite.texture?.filteringMode = .nearest
		node.addChild(sprite)

		let plate = SKSpriteNode(imageNamed: "HP\(stats.hp)")
		plate.position = CGPoint(x: 0, y: -12.0)
		plate.zPosition = 2.3
		plate.texture?.filteringMode = .nearest
		plate.name = "hp"
		node.addChild(plate)

		return node
	}

	var imageName: String {
		switch stats.unitType {
		case .fighter:
			switch stats.moveType {
			case .leg: "Inf"
			case .wheel: "Truck"
			case .track:
				switch stats.targetType {
				case .heavy: "Tank"
				default: "Recon"
				}
			case .air: "MH6"
			}
		case .art: "Art"
		case .aa: "AA"
		case .support: "Truck"
		}
	}
}

extension SKNode {

	var unitHP: SKSpriteNode? {
		childNode(withName: "hp") as? SKSpriteNode
	}

	func update(hp: UInt8) {
		unitHP?.texture = .init(imageNamed: "HP\(hp)")
	}

	func showSight(for duration: TimeInterval) {
		let sight = SKSpriteNode(imageNamed: "Sight")
		sight.texture?.filteringMode = .nearest
		addChild(sight)

		sight.run(.sequence([
			.wait(forDuration: duration),
			.removeFromParent()
		]))
	}
}

extension BuildingType {

	var imageName: String {
		switch self {
		case .city: "City"
		}
	}

	var tile: SKTileGroup {
		switch self {
		case .city: .city
		}
	}
}
