import COR

enum Direction { case right, up, left, down }
enum Target { case prev, next }
enum InputAction { case a, b, c, d }

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
	case target(Target?)
	case action(InputAction?, modifiers: InputModifiers)
	case menu
	case tile(XY)
	case scale(Int)
	case pan(XY)
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

	func neighbor(_ direction: Direction) -> XY {
		switch direction {
		case .right: XY(1, 0) + self
		case .up: XY(0, 1) + self
		case .left: XY(-1, 0) + self
		case .down: XY(0, -1) + self
		}
	}
}
