public enum Reaction<Action, Event> {
	case action(Action)
	case events([Event])

	public static var none: Reaction { .events([]) }
}
