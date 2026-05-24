enum Direction { case right, up, left, down }
enum Target { case prev, next }
enum Action { case a, b, c, d }

enum Input: Equatable {
	case direction(Direction?)
	case target(Target?)
	case action(Action?)
	case menu, mode
	case tile(XY)
	case scale(Int)
	case pan(XY)
}
