import SpriteKit
import UIKit
import COR

extension Unit {

	@MainActor
	var hqSprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(texture: SKTexture(image: image))
		sprite.zPosition = 0.2
		sprite.texture?.filteringMode = .nearest
		node.addChild(sprite)

		return node
	}

	@MainActor
	var sprite: SKNode {
		let node = SKNode()

		let sprite = SKSpriteNode(texture: SKTexture(image: image))
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

	var image: UIImage {
		switch model {
		case .none: .clear
		case .truck: .truck

		// Infantry
		case .regular, .engineer, .ranger, .militia: .reg
		case .delta, .ksk, .speznas: .SF

		// Artillery
		case .art155, .m777, .art105: .art
		case .m270: .m270
		case .pzh: .PZH

		// Anti-air
		case .patriot, .nasams: .NASAMS
		case .bofors: .flak
		case .neva, .s300: .neva
		case .lvkv90, .tunguska: .SPAA

		// IFV / recon
		case .fennek, .boxer, .brdm2: .boxer
		case .kf41: .puma
		case .m2A2, .m113, .strf90, .strf90v, .cv9035, .bmp: .recon

		// Tanks
		case .m48, .m1A1, .m1A2: .M_1_A_2
		case .leo1, .strv103, .strv122, .kf51, .leo2a6: .tank
		case .t55, .t72, .t90m: .T_72

		// Air
		case .skeldar, .skeldarm: .skeldar
		case .mh6, .mq9, .nh90, .mi8, .mi24: .MH_6
		case .orlan: .fixedWing
		case .f16, .f35: .F_16
		case .gripen, .mig29, .su57, .su25, .su27: .F_64
		}
	}
}

extension Country {

	var flag: UIImage {
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
