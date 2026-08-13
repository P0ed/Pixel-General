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
		plate.position = CGPoint(x: 0, y: -12.0)
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

	/// The GFX silhouette a unit is drawn with. Models sharing a shape share a sprite.
	var vehicle: Units.Shape? {
		switch model {
		case .none: nil
		case .truck: .truck

		// Infantry
		case .regular, .engineer, .ranger, .militia: .rifleman
		case .delta, .ksk, .speznas: .special
		case .fpv, .p1sun: .quad

		// Artillery
		case .art155, .m777, .art105: .gun
		case .sp105, .pzh, .m109: .artillery
		case .mars, .m147: .launcher

		// Anti-air
		case .patriot, .nasams, .neva, .s300: .launcher
		case .bofors: .flak
		case .lvkv90, .tunguska: .spaa

		// IFV / recon
		case .fennek: .fennek
		case .brdm2: .brdm2
		case .boxer: .carrier
		case .m2A2, .m113, .marder, .bmp: .recon
		case .strf90, .cv9035, .kf41: .ifv

		// Tanks
		case .m48, .m1A1, .m1A2: .heavyTank
		case .strv122, .kf51, .leo2a6: .leo2
		case .leo1, .strv103: .tank
		case .t55, .t72, .t90m: .lowTank

		// Air
		case .skeldar, .skeldarm: .scout
		case .mh6, .nh90, .mi8, .mi24: .helicopter
		case .mq9, .orlan: .drone
		case .f16, .f35: .jet
		case .gripen, .mig29, .su57, .su25, .su27: .heavyJet

		// Naval
		case .cargo: .cargo
		case .destroyer: .destroyer
		case .cruiser: .cruiser
		}
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
