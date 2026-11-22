import SpriteKit
import UIKit
import COR
import GFX

extension Unit {

	@MainActor
	var hqSprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(texture: image)
		sprite.anchorPoint = .vehicle
		sprite.zPosition = 0.2
		node.addChild(sprite)

		return node
	}

	@MainActor
	var sprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(texture: image)
		sprite.blendMode = .alpha
		sprite.colorBlendFactor = 0.2
		sprite.color = country.color
		sprite.zPosition = 0.2
		sprite.anchorPoint = .vehicle
		node.addChild(sprite)

		let plate = SKSpriteNode(texture: .hp(hp))
		plate.position = CGPoint(x: 0, y: -CGSize.tile.height * 3 / 8)
		plate.zPosition = 2.3
		plate.name = "hp"
		node.addChild(plate)

		return node
	}

	@MainActor
	var image: SKTexture {
		guard let vehicle else { return .clear }
		return .vehicle(vehicle, mirrored: country.team != .axis)
	}

}

extension Country {

	@MainActor
	var flag: SKTexture {
		switch self {
		case .usa: .usa
		case .swe: .swe
		case .ukr: .ukr
		case .irn: .irn
		case .isr: .isr
		case .rus: .rus
		case .pak: .pak
		case .ind: .ind
		case .den: .den
		case .ned: .ned
		case .aut: .aut
		case .nor: .nor
		case .fin: .fin
		case .ger: .ger
		case .est: .est
		case .lva: .lva
		case .ltu: .ltu
		case .pol: .pol
		case .bel: .bel
		case .cze: .cze
		case .svk: .svk
		case .rom: .rom
		case .hun: .hun
		case .mol: .mol
		case .none: .clear
		}
	}
}

extension SKNode {

	var unitHP: SKSpriteNode? {
		childNode(withName: "hp") as? SKSpriteNode
	}

	func update(hp: UInt8) {
		unitHP.map { $0.texture = .hp(hp) }
	}

	func showSight(for duration: TimeInterval) {
		let sight = SKSpriteNode(texture: .sight)
		addChild(sight)

		sight.run(.sequence([
			.wait(forDuration: duration),
			.removeFromParent()
		]))
	}
}
