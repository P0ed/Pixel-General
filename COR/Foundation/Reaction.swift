public enum Reaction<Action, Event> {
	case action(Action)
	case events([Event])
	case none
}
