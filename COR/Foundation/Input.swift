@frozen public enum Direction { case right, up, left, down }
@frozen public enum Target { case prev, next }
@frozen public enum Action { case a, b, c, d }

@frozen public struct InputModifiers: OptionSet, Equatable, Sendable {
	public let rawValue: UInt8

	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}

	public static let left = InputModifiers(rawValue: 1 << 0)
	public static let right = InputModifiers(rawValue: 1 << 1)
}

@frozen public enum Input: Equatable {
	case direction(Direction?, modifiers: InputModifiers)
	case target(Target?)
	case action(Action?, modifiers: InputModifiers)
	case menu, mode
	case tile(XY)
	case scale(Int)
	case pan(XY)
}

public extension Input {

	static func direction(_ direction: Direction?) -> Input {
		.direction(direction, modifiers: [])
	}

	static func action(_ action: Action?) -> Input {
		.action(action, modifiers: [])
	}
}
