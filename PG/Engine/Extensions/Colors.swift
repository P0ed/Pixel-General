import SpriteKit

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

	static var graySurface: SKColor { .hex(0xA0A0A0) }
	static var blueSurface: SKColor { .hex(0x75CDFF) }
	static var yellowSurface: SKColor { .hex(0xF7EF73) }
	static var greenSurface: SKColor { .hex(0x64B738) }
	static var redSurface: SKColor { .hex(0xE8B26F) }
}
