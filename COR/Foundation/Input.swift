public enum Direction { case right, up, left, down }
public enum Target { case prev, next }
public enum Action { case a, b, c, d }

public enum Input: Equatable {
	case direction(Direction?)
	case target(Target?)
	case action(Action?)
	case menu, mode
	case tile(XY)
	case scale(Int)
	case pan(XY)
}
