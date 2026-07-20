import SpriteKit
import COR

private func * (color: SKColor, alpha: CGFloat) -> SKColor {
	color.withAlphaComponent(alpha)
}

extension SKColor {

	static func hex(_ rgb: UInt32) -> SKColor {
		SKColor(
			red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
			green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
			blue: CGFloat((rgb >> 0) & 0xFF) / 255.0,
			alpha: 1.0
		)
	}

	static var baseSelection: SKColor { SKColor.hex(0x7F7F7F) * 0.47 }
	static var baseCursor: SKColor { .hex(0x303030) * 0.33 }

	static var lineSelection: SKColor { .hex(0x303030) * 0.47 }
	static var lineCursor: SKColor { .hex(0x303030) * 0.82 }

	static var selectedCursor: SKColor { .hex(0xE06050) }

	static var textDefault: SKColor { .hex(0x010101) }

	static var fieldSurface: SKColor { .hex(0xDAD8D6) }
	static var forestSurface: SKColor { .hex(0xA0C0A7) }
	static var waterSurface: SKColor { .hex(0x90C0F0) }
	static var seaSurface: SKColor { .hex(0x507CA8) }

	static var lightSurface: SKColor { .hex(0xBFBFBF) }
	static var darkSurface: SKColor { .hex(0x8F8F8F) }
	static var graySurface: SKColor { Country.none.color }

	static func amberGreen8(_ level: UInt8) -> SKColor {
		let cl = UInt32(min(level, 7))
		let r = 0xBF - 9 * cl as UInt32
		let g = 0x9F + 9 * cl as UInt32
		let b = 0x2F - 5 * cl as UInt32
		return .hex(r << 16 | g << 8 | b)
	}
}

extension Team {

	var color: SKColor {
		switch self {
		case .axis: Country.swe.color
		case .allies: Country.isr.color
		case .soviet: Country.rus.color
		case .none: Country.none.color
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
}
