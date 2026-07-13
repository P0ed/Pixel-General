enum InputReaction<Action, PresentationIntent> {
	case action(Action)
	case presentation(PresentationIntent)
	case none
}
