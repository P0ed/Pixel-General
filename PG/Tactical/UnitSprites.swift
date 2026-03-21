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
		sprite.blendMode = .alpha
		sprite.colorBlendFactor = 0.1
		sprite.color = country.color
		sprite.zPosition = 0.2
		sprite.xScale = country.team == .axis ? 1.0 : -1.0
		sprite.texture?.filteringMode = .nearest
		node.addChild(sprite)

		let plate = SKSpriteNode(imageNamed: "HP\(hp)")
		plate.position = CGPoint(x: 0, y: -12.0)
		plate.zPosition = 2.3
		plate.texture?.filteringMode = .nearest
		plate.name = "hp"
		node.addChild(plate)

		return node
	}

	var imageName: String {
		switch type {
		case .soft:
			if self[.art] { "Art" }
			else if self[.hardcore] { "SF" }
			else { "Reg" }
		case .softWheel:
			if self[.supply] { "Truck" }
			else if self[.aa] { "Neva" }
			else { "Truck" }
		case .lightWheel: "boxer"
		case .lightTrack:
			if self[.radar] { "SPAA" }
			else if self[.art] { "PZH" }
			else { "Recon" }
		case .heavyTrack:
			switch country {
			case .usa: "M1A1"
			default: "Tank"
			}
		case .heli: "MH6"
		case .jet: "F64"
		}
	}
}

extension Country {

	var color: SKColor {
		switch self {
		case .usa: .red
		case .swe: .blue
		case .ukr: .yellow
		case .rus: .green
		default: .white
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
