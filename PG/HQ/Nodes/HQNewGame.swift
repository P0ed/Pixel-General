import SpriteKit

extension HQNodes {

	func newGameMenu(_ state: borrowing HQState) -> MenuState<HQAction> {
		MenuState<HQAction>(
			items: Country.allCases.map { c in
				.close(
					icon: "\(c)",
					status: "\(c)",
					update: { _ in
						core.new(country: c)
						present(.make(core.state))
					}
				)
			}
		)
	}
}

private extension PlayerType {

	mutating func toggle() {
		self = switch self {
		case .human: .ai
		case .ai: .remote
		case .remote: .human
		}
	}

	var icon: String {
		switch self {
		case .human: "Human"
		case .ai: "AI"
		case .remote: "Remote"
		}
	}
}
