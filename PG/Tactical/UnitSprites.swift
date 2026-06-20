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
		switch type {
		case .aa: rng > 1 ? .NASAMS : .flak
		case .wheelArt: .clear
		case .supply: .truck
		case .inf: if self[.elite] { .SF } else { .reg }
		case .art: .art
		case .trackArt:
			switch country.team {
			case .axis: .PZH
			case .allies: .m270
			case .soviet: .akatsiya
			case .none: .clear
			}
		case .wheelAA: .neva
		case .trackAA: .SPAA
		case .lightWheel: .boxer
		case .lightTrack:
			self[.elite] ? .puma : .recon
		case .heavyTrack:
			switch country.team {
			case .allies: .M_1_A_2
			case .axis: .tank
			case .soviet: .T_72
			case .none: .clear
			}
		case .heli:
			switch country.team {
			case .axis:
				if tier == 0 { .MH_6 } else { .skeldar }
			default: .MH_6
			}

		case .fighter:
			switch country.team {
			case .allies: .F_16
			default: .F_64
			}
		case .cas: .F_64
		}
	}
}

extension Country {

	var color: SKColor {
		switch self {
		case .usa: .purple
		case .swe: .systemYellow
		case .ukr: .yellow
		case .den: .white
		case .ned: .orange
		case .rus: .red
		case .irn: .cyan
		case .pak: .green
		case .ind: .orange
		case .isr: .blue
		// Placeholder: campaign nations are tinted by team until bespoke colors land.
		default:
			switch team {
			case .axis: .systemYellow
			case .allies: .blue
			case .soviet: .red
			case .none: .gray
			}
		}
	}

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
