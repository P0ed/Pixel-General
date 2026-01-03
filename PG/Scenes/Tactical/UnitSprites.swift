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
		switch stats.type {
		case .soft:
			if stats[.art] { "Art" }
			else { "Inf" }
		case .softWheel:
			if stats[.supply] { "Truck" }
			else if stats[.aa] { "Neva" }
			else { "Truck" }
		case .lightWheel, .mediumWheel: "Truck"
		case .lightTrack, .mediumTrack:
			if stats[.aa] { "SPAA" }
			else if stats[.art] { "PZH" }
			else { "Recon" }
		case .heavyTrack: "Tank"
		case .air: "MH6"
		}
	}
}

extension SKNode {

	var unitHP: SKSpriteNode? {
		childNode(withName: "hp") as? SKSpriteNode
	}

	func update(hp: UInt8) {
		unitHP.map {
			$0.texture = .init(imageNamed: "HP\(hp)")
			$0.texture?.filteringMode = .nearest
		}
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
