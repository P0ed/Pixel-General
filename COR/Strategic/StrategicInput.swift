public extension StrategicState {

	mutating func apply(_ input: Input) -> Reaction<StrategicAction, StrategicEvent> {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .tile(let xy): select(xy)
		case .action(.a): attack(at: cursor)
		case .menu: .events([.menu])
		default: .none
		}
	}

	private mutating func moveCursor(_ direction: Direction) -> Reaction<StrategicAction, StrategicEvent> {
		let xy = cursor.neighbor(direction)
		if owner.contains(xy) { cursor = xy }
		return .none
	}

	private mutating func select(_ xy: XY) -> Reaction<StrategicAction, StrategicEvent> {
		guard owner.contains(xy) else { return .none }
		cursor = xy
		return attack(at: xy)
	}

	private func attack(at xy: XY) -> Reaction<StrategicAction, StrategicEvent> {
		canAttack(xy) ? .action(.attack(xy)) : .none
	}
}
