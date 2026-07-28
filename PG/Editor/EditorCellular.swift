import SpriteKit
import COR

extension EditorNodes {

	/// Configuration page for the height automaton. The five knobs are
	/// `update`-only: `Scene.didSetMenu` dispatches an item's `action` *before*
	/// running its `update`, so a knob that carried its own action would always
	/// send the value from the previous tap. Instead each knob re-stamps the
	/// two step buttons, and the rule travels with the action that runs it.
	///
	/// The step buttons return the menu unchanged rather than closing, so the
	/// map can be evolved one generation per tap with the page still open.
	func cellularMenu(
		_ menu: MenuState<EditorAction>,
		_ state: borrowing EditorState
	) -> MenuState<EditorAction> {
		var rule = state.cellularRule()

		/// A config cell: mutate the captured rule, then re-render every label
		/// and re-stamp the step buttons. Icon and status here are placeholders
		/// — `refresh` owns them.
		func knob(_ change: @MainActor @escaping () -> Void) -> MenuItem<EditorAction> {
			MenuItem(icon: .clear, status: .init(), update: { m in
				modifying(m) { m in
					change()
					m.refresh(rule)
				}
			})
		}

		let knobs = [
			knob { rule.cycleKind() },
			knob { rule.cycleNeighborhood() },
			knob { rule.rise.toggle4() },
			knob { rule.fall.toggle4() },
			knob { rule.noise.toggle4() },
		]

		let buttons: [MenuItem<EditorAction>] = [
			.init(icon: .rnd, status: .init(text: "Scatter heights"), action: .scatter, update: { $0 }),
			.init(icon: .empty, status: .init(text: "Flatten heights"), action: .flatten, update: { $0 }),
			.init(icon: .start, status: .init(text: "Step"), update: { $0 }),
			.init(icon: .restart, status: .init(text: "Step ×8"), update: { $0 }),
		]

		return modifying(
			MenuState(
				items: knobs + [.space, .space, .space] + buttons,
				close: { _ in menu }
			)
		) { m in
			m.refresh(rule)
		}
	}
}

private extension MenuState<EditorAction> {

	/// Rewrites the five knob cells and re-stamps the two step actions. Called
	/// after every change because the thresholds are labelled in real neighbour
	/// counts, which depend on both the rule kind and the neighbourhood size.
	mutating func refresh(_ rule: Cellular) {
		items[0].icon = .spawn(rule.kind.rawValue)
		items[0].status.text = "Rule: \(rule.kindName)"
		items[1].icon = .spawn(rule.neighborhood)
		items[1].status.text = "Neighborhood: \(rule.cellsLabel)"
		items[2].icon = .toggle4(rule.rise)
		items[2].status.text = "Rise: \(rule.riseLabel)"
		items[3].icon = .toggle4(rule.fall)
		items[3].status.text = "Fall: \(rule.fallLabel)"
		items[4].icon = .toggle4(rule.noise)
		items[4].status.text = "Noise: \(rule.noise)/16"
		items[10].action = .cellular(rule, steps: 1)
		items[11].action = .cellular(rule, steps: 8)
	}
}

extension Cellular {

	var kindName: String {
		switch kind {
		case .terrace: "Terrace — uplift / erosion"
		case .cyclic: "Cyclic — spiral waves"
		case .ridges: "Ridges — labyrinths"
		}
	}

	/// `.ridges` fixes its own two rings, so the neighborhood knob is inert.
	var cellsLabel: String {
		kind == .ridges ? "8 + 12 rings (fixed)" : "\(cells) cells"
	}

	var riseLabel: String {
		switch kind {
		case .terrace: "sum ≥ \(riseSum) of \(cells * 2)"
		case .cyclic: "≥\(riseCount) of \(cells) ahead"
		case .ridges: "score ≥ \(riseScore)"
		}
	}

	var fallLabel: String {
		switch kind {
		case .terrace: "sum ≤ \(fallSum) of \(cells * 2)"
		case .cyclic: "— (unused)"
		case .ridges: "score ≤ -\(fallScore)"
		}
	}

	mutating func cycleKind() {
		kind = Kind(rawValue: (kind.rawValue + 1) % UInt8(Kind.allCases.count)) ?? .terrace
	}

	mutating func cycleNeighborhood() {
		neighborhood = (neighborhood + 1) % 3
	}
}
