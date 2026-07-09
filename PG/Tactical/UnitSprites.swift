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

	/// Per-nation identity color, HoI/EU-style: derived from each flag's most
	/// distinctive color, with tones spread so campaign-map neighbors never
	/// blur together. Read two ways, both must hold up: a subtle 10% tint over
	/// grayscale unit sprites, and a full opaque fill in "country" map mode.
	/// So: mid-tone, moderate saturation (no neon, no near-black/white).
	/// Verified with CIEDE2000: ≥ 16 for every campaign border pair (and vs
	/// the 0x808080 sea), ≥ 8 for any two countries (tactical matchups).
	/// Europe's flags are mostly red/white/blue, so where a border pair shares
	/// a flag color, one side takes a secondary flag color or shifts tone —
	/// e.g. Norway goes salmon next to crimson Russia, Austria takes its white
	/// stripe (the classic EU-game silver) amid red-flagged neighbors.
	var color: SKColor {
		switch self {
		// Nordics
		case .swe: .hex(0x3F7FD6) // flag blue
		case .nor: .hex(0xD2695E) // flag red, salmon (clear of crimson rus)
		case .fin: .hex(0xA6C6DF) // white field, blue cross — pale steel
		case .den: .hex(0xD22E4B) // flag red, bright crimson
		// Baltics
		case .est: .hex(0x47828F) // flag blue + black — steel teal
		case .lva: .hex(0x93445C) // flag carmine, wine
		case .ltu: .hex(0xC08A2E) // flag yellow stripe, ochre gold
		// West & Central
		case .ned: .hex(0xD96A24) // royal orange
		case .ger: .hex(0x4E545E) // flag black stripe — field gray
		case .pol: .hex(0xC75B78) // white-red — rose
		case .cze: .hex(0x2568A6) // flag triangle blue, cerulean
		case .svk: .hex(0x8CA9D6) // flag blue, pale periwinkle
		case .aut: .hex(0xBEB6A6) // white stripe — silver
		case .hun: .hex(0x4E8047) // flag green
		// East
		case .ukr: .hex(0xE3BC3F) // flag yellow
		case .bel: .hex(0x7FA33B) // flag green, chartreuse lean
		case .mol: .hex(0xA94A2E) // flag red, brick
		case .rom: .hex(0x4053A8) // flag cobalt blue
		case .rus: .hex(0x992A24) // flag red, dark soviet crimson
		// Off-map
		case .usa: .hex(0x4A5578) // flag navy, slate
		case .isr: .hex(0x62B7D9) // flag blue on white, light azure
		case .pak: .hex(0x275E43) // flag deep green
		case .irn: .hex(0x2FA05C) // flag green, emerald
		case .ind: .hex(0xEB9C4C) // saffron
		case .none: .hex(0x808080) // neutral / unowned / sea
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
