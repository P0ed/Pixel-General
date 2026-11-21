import CoreGraphics
import COR

enum Direction { case right, up, left, down }
enum Target { case prev, next }
enum InputAction { case a, b, c, d }

extension InputAction {

	static let all: [InputAction] = [.a, .b, .c, .d]

	/// Position on a menu side panel, `A` topmost.
	var index: Int {
		switch self {
		case .a: 0
		case .b: 1
		case .c: 2
		case .d: 3
		}
	}
}

struct InputModifiers: OptionSet, Equatable, Sendable {
	let rawValue: UInt8

	init(rawValue: UInt8) {
		self.rawValue = rawValue
	}

	static let left = InputModifiers(rawValue: 1 << 0)
	static let right = InputModifiers(rawValue: 1 << 1)
}

enum Input: Equatable {
	case direction(Direction?, modifiers: InputModifiers)
	case action(InputAction?, modifiers: InputModifiers)
	case target(Target?)
	case menu
	case tile(XY)
	case scale(Int)
	case pan(CGPoint)
}

extension Input {

	static func direction(_ direction: Direction?) -> Input {
		.direction(direction, modifiers: [])
	}

	static func action(_ action: InputAction?) -> Input {
		.action(action, modifiers: [])
	}
}

extension XY {

	func panned(by offset: CGPoint, size: Int) -> XY {
		let limit = CGFloat(size - 1)
		return XY(
			Int(min(limit, max(0, CGFloat(x) + offset.x.rounded()))),
			Int(min(limit, max(0, CGFloat(y) + offset.y.rounded())))
		)
	}

	func neighbor(_ direction: Direction) -> XY {
		switch direction {
		case .right: XY(x + 1, y)
		case .up: XY(x, y + 1)
		case .left: XY(x - 1, y)
		case .down: XY(x, y - 1)
		}
	}

	func diagonal(_ direction: Direction) -> XY {
		switch direction {
		case .right: XY(x + 1, y + 1)
		case .up: XY(x - 1, y + 1)
		case .left: XY(x - 1, y - 1)
		case .down: XY(x + 1, y - 1)
		}
	}
}
