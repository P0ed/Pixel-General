import SpriteKit
import UIKit

@MainActor
extension SKTexture {

	// Sliced
	static let menu = pixels(.menu)

	// Decorations.spriteatlas
	static let BTN_0 = pixels(.BTN_0)
	static let BTN_1 = pixels(.BTN_1)
	static let cursor = pixels(.cursor)
	static let highlighted = pixels(.highlighted)
	static let HP_0 = pixels(.HP_0)
	static let HP_1 = pixels(.HP_1)
	static let HP_2 = pixels(.HP_2)
	static let HP_3 = pixels(.HP_3)
	static let HP_4 = pixels(.HP_4)
	static let HP_5 = pixels(.HP_5)
	static let HP_6 = pixels(.HP_6)
	static let HP_7 = pixels(.HP_7)
	static let HP_8 = pixels(.HP_8)
	static let HP_9 = pixels(.HP_9)
	static let HP_10 = pixels(.HP_10)
	static let HP_11 = pixels(.HP_11)
	static let HP_12 = pixels(.HP_12)
	static let HP_13 = pixels(.HP_13)
	static let HP_14 = pixels(.HP_14)
	static let HP_15 = pixels(.HP_15)
	static let sight = pixels(.sight)

	// Icons
	static let AI = pixels(.AI)
	static let arrowDown = pixels(.arrowDown)
	static let arrowLeft = pixels(.arrowLeft)
	static let arrowRight = pixels(.arrowRight)
	static let arrowUp = pixels(.arrowUp)
	static let chess = pixels(.chess)
	static let clear = pixels(.clear)
	static let HQ = pixels(.HQ)
	static let human = pixels(.human)
	static let I = pixels(.I)
	static let II = pixels(.II)
	static let III = pixels(.III)
	static let IV = pixels(.IV)
	static let minus = pixels(.minus)
	static let plus = pixels(.plus)
	static let prestige1 = pixels(.prestige1)
	static let prestige2 = pixels(.prestige2)
	static let remote = pixels(.remote)
	static let restart = pixels(.restart)
	static let rnd = pixels(.rnd)
	static let settings = pixels(.settings)
	static let sound0 = pixels(.sound0)
	static let sound1 = pixels(.sound1)
	static let sound2 = pixels(.sound2)
	static let V = pixels(.V)
	static let value0 = pixels(.value0)
	static let value1 = pixels(.value1)
	static let value2 = pixels(.value2)
	static let value3 = pixels(.value3)

	// Flags
	static let aut = pixels(.aut)
	static let bel = pixels(.bel)
	static let cze = pixels(.cze)
	static let den = pixels(.den)
	static let est = pixels(.est)
	static let fin = pixels(.fin)
	static let ger = pixels(.ger)
	static let hun = pixels(.hun)
	static let ind = pixels(.ind)
	static let irn = pixels(.irn)
	static let isr = pixels(.isr)
	static let ltu = pixels(.ltu)
	static let lva = pixels(.lva)
	static let mol = pixels(.mol)
	static let ned = pixels(.ned)
	static let neutral = pixels(.neutral)
	static let nor = pixels(.nor)
	static let pak = pixels(.pak)
	static let pol = pixels(.pol)
	static let rom = pixels(.rom)
	static let rus = pixels(.rus)
	static let svk = pixels(.svk)
	static let swe = pixels(.swe)
	static let ukr = pixels(.ukr)
	static let usa = pixels(.usa)

	private static func pixels(_ image: UIImage) -> SKTexture {
		let texture = SKTexture(image: image)
		texture.filteringMode = .nearest
		return texture
	}
}

@MainActor
extension SKTexture {

	static func toggle(_ value: Bool) -> SKTexture {
		value ? .plus : .minus
	}

	static func toggle4(_ value: UInt8) -> SKTexture {
		switch value {
		case 0: .value0
		case 1: .value1
		case 2: .value2
		default: .value3
		}
	}

	static func number(_ value: UInt8) -> SKTexture? {
		switch value {
		case 0: .I
		case 1: .II
		case 2: .III
		case 3: .IV
		case 4: .V
		default: nil
		}
	}

	static func spawn(_ value: UInt8) -> SKTexture {
		number(value) ?? .rnd
	}

	static func sound(_ level: UInt8) -> SKTexture {
		switch level {
		case 0: .sound0
		case 1: .sound1
		default: .sound2
		}
	}

	static func hp(_ hp: UInt8) -> SKTexture {
		switch hp {
		case 0: .HP_0
		case 1: .HP_1
		case 2: .HP_2
		case 3: .HP_3
		case 4: .HP_4
		case 5: .HP_5
		case 6: .HP_6
		case 7: .HP_7
		case 8: .HP_8
		case 9: .HP_9
		case 10: .HP_10
		case 11: .HP_11
		case 12: .HP_12
		case 13: .HP_13
		case 14: .HP_14
		default: .HP_15
		}
	}
}
