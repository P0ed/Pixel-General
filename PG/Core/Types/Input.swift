enum Direction { case right, up, left, down }
enum Target { case prev, next }
enum Action { case a, b, c, d }

enum Input {
	case direction(Direction?)
	case target(Target?)
	case action(Action?)
	case menu
	case tile(XY)
	case scale(Double)
}
