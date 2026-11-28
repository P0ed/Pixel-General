import SpriteKit
import UIKit
import COR
import GFX

typealias Unit = COR.Unit

extension Unit {

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

	/// Named platforms have their own geometry. Common equipment uses the faction's variant.
	var vehicle: Units.Shape? {
		switch model {
		case .none: nil
		case .truck: Units.Kind.supply.variant(for: artFaction)

		case .regular, .ranger, .militia: .rifleman
		case .engineer: .engineer
		case .delta, .ksk, .speznas: .special
		case .fpv, .p1sun: .fpv

		case .art155: switch country.team {
		case .soviet: .d20
		case .allies: .m198
		default: .fh70
		}
		case .m777: .m777
		case .art105: .d30
		case .sp105: .akatsiya
		case .pzh: .pzh2000
		case .m109: .m109
		case .mars: .m270
		case .m147: .m142

		case .patriot: .patriot
		case .nasams: .nasams
		case .neva: .neva
		case .s300: .s300
		case .bofors: Units.Kind.towedAA.variant(for: artFaction)
		case .lvkv90: .lvkv90
		case .tunguska: .tunguska

		case .fennek: .fennek
		case .brdm2: .brdm2
		case .boxer: .boxer
		case .m2A2: .m2A2
		case .m113: .m113
		case .marder: .marder
		case .bmp: .bmp2
		case .strf90: .strf90
		case .cv9035: .cv9035
		case .kf41: .kf41

		case .m48: .m48
		case .m1A1: .m1A1
		case .m1A2: .m1A2
		case .kf51: .kf51
		case .leo2a4: .leo2a4
		case .leo2a7: .leo2a7
		case .strv122: .strv122
		case .leo1a5: .leo1a5
		case .t55: .t55
		case .t72: .t72
		case .t90m: .t90m

		case .skeldar: .skeldar
		case .skeldarm: .skeldarm
		case .mh6: .mh6
		case .nh90: .nh90
		case .mi8: .mi8
		case .mi24: .mi24
		case .mq9: .mq9
		case .orlan: .orlan
		case .f16: .f16
		case .f35: .f35
		case .gripen: .gripen
		case .mig29: .mig29
		case .su57: .su57
		case .su25: .su25
		case .su27: .su27

		case .cargo: Units.Kind.cargo.variant(for: artFaction)
		case .destroyer: Units.Kind.destroyer.variant(for: artFaction)
		case .cruiser: Units.Kind.cruiser.variant(for: artFaction)
		}
	}

	private var artFaction: Units.Faction {
		switch country.team {
		case .allies: .american
		case .soviet: .soviet
		case .axis, .none: .european
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
