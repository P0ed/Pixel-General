@frozen public enum Direction { case right, up, left, down }
@frozen public enum Target { case prev, next }
@frozen public enum Action { case a, b, c, d }

@frozen public enum Input: Equatable {
	case direction(Direction?)
	case target(Target?)
	case action(Action?)
	case menu, mode
	case tile(XY)
	case scale(Int)
	case pan(XY)
}
