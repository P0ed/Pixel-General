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

extension Team {
	var color: SKColor {
		switch self {
		case .axis: .blueSurface
		case .allies: .yellowSurface
		case .soviet: .redSurface
		case .none: .greenSurface
		}
	}
}

extension Country {

	/// Per-nation identity color. Read two ways, both must hold up: a subtle 10%
	/// tint over grayscale unit sprites, and a full opaque fill in "country" map
	/// mode. So: mid-tone, moderate saturation (no neon, no near-black/white), and
	/// clear of the muted terrain + gray. Each team gets a hue family — axis cool
	/// (teal→blue→violet), soviet warm (red→orange→magenta), allies green — with
	/// hue/lightness varied within so every nation stays distinct. Ordered by hue.
	var color: SKColor {
		switch self {
		// Axis — cool: teal → blue → indigo → violet
		case .est: .hex(0x2DA9A5) // dark teal
		case .den: .hex(0x26A5C5) // cyan-teal
		case .fin: .hex(0x8BD0DA) // light aqua
		case .nor: .hex(0x2986BC) // cerulean
		case .swe: .hex(0x458FE3) // sky blue
		case .ned: .hex(0x2467DB) // royal blue
		case .ger: .hex(0x394593) // deep navy
		case .ukr: .hex(0x6C73DA) // periwinkle
		case .lva: .hex(0x5943C7) // indigo
		case .ltu: .hex(0xA886E4) // light violet
		case .pol: .hex(0x8E38C7) // violet
		case .cze: .hex(0x8E2A9D) // purple
		case .aut: .hex(0xD987D9) // orchid
		// Soviet — warm: red → orange → amber → rose → magenta
		case .rus: .hex(0xBC3329) // crimson
		case .ind: .hex(0xA55431) // terracotta
		case .rom: .hex(0xE16D33) // scarlet-orange
		case .mol: .hex(0xEA9A3E) // pumpkin orange
		case .hun: .hex(0xCDA82D) // amber gold
		case .bel: .hex(0xA38043) // khaki brown
		case .svk: .hex(0xD67471) // dusty rose
		case .irn: .hex(0xC43B80) // raspberry magenta
		// Allies — green: emerald → grass → olive
		case .isr: .hex(0x2EA378) // emerald
		case .pak: .hex(0x55AE37) // grass green
		case .usa: .hex(0xAABF40) // olive
		case .none: .hex(0x808080) // neutral / unowned
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
