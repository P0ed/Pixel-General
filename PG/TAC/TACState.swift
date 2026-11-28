import COR

enum MapMode: UInt8, Hashable {
	case terrain, supply, country, team, defense
}

@MainActor
struct TACUIState: ~Copyable {
	var cursor: XY = .zero
	var camera: XY = .zero
	var selectedUnit: UID = .none
	var selectable: SetXY?
	var scale: Int = 1
	var mapMode: MapMode = .terrain
	var autoBattle: Bool = false
}

@MainActor
struct TACSceneState: ~Copyable {
	var tac: TACState
	var ui: TACUIState

	init(tac: consuming TACState, ui: consuming TACUIState = TACUIState()) {
		self.tac = tac
		self.ui = ui
	}

	mutating func reduce(_ action: Action) -> [Event] {
		if tac.isFinished { return [] }

		let events = tac.reduce(action)

		switch action {
		case .move(let uid, _), .attack(let uid, _):
			if tac.player.type == .human {
				let keep = tac.units[uid].alive && tac.units[uid].hasActions || tac.cargo[uid] != .none
				ui.selectedUnit = keep ? uid : .none
			}
		case .embark(_, let transport) where tac.player.type == .human:
			ui.selectedUnit = transport
		case .end: ui.selectedUnit = .none
		case .abandon: abandon()
		default: break
		}

		if tac.player.type != .human, let focus = action.cameraFocus(in: tac) {
			let cam = ui.camera
			let across = (focus.x + focus.y) - (cam.x + cam.y)
			let depth = (focus.y - focus.x) - (cam.y - cam.x)
			if abs(across) > 8 * ui.scale || abs(depth) > 10 * ui.scale {
				ui.camera = focus.clamped(tac.map.size)
			}
		}

		refreshSelectable()
		return events
	}

	private mutating func abandon() {
		core.complete(tac)
		tac.isFinished = true
		ui.selectedUnit = .none
		ui.selectable = nil
		ui.autoBattle = false
		core.save()
	}

	private mutating func refreshSelectable() {
		ui.selectable = ui.selectedUnit != .none && tac.units[ui.selectedUnit].canMove
			? tac.moves(for: ui.selectedUnit).setXY : nil
	}
}

private extension Action {

	func cameraFocus(in sim: borrowing TACState) -> XY? {
		switch self {
		case .move(let uid, _), .embark(let uid, _), .resupply(let uid):
			let xy = sim.position[uid]
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .disembark(_, let xy):
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .attack(let src, let dst):
			let s = sim.position[src], d = sim.position[dst]
			return sim.isVisibleToHuman(s) ? s : sim.isVisibleToHuman(d) ? d : nil
		case .purchase, .end, .abandon:
			return nil
		}
	}
}

enum PresentationIntent {
	case shop
	case menu
}


enum InputReaction {
	case action(Action)
	case presentation(PresentationIntent)
	case none
}

extension TACSceneState {

	mutating func apply(_ input: Input) -> InputReaction {
		if tac.isFinished {
			switch input {
			case .menu, .action(.a, modifiers: []): return .presentation(.menu)
			case .tile(let xy):
				if tac.map.contains(xy) { ui.cursor = xy }
				return .none
			case .action(let action?, modifiers: .right): return setMapMode(action)
			case .pan, .scale, .direction: break
			default: return .none
			}
		}
		defer { refreshSelectable() }

		return switch input {
		case .direction(let direction?, modifiers: let modifiers):
			directionalAction(direction, modifiers: modifiers)
		case .action(let action?, modifiers: let modifiers):
			buttonAction(action, modifiers: modifiers)
		case .target(.prev): prevUnit()
		case .target(.next): nextUnit()
		case .tile(let xy): select(xy)
		case .scale(let value): { ui.scale = value; return .none }()
		case .pan(let offset):
			{ ui.camera = ui.camera.panned(by: offset, size: tac.map.size); return .none }()
		case .menu: .presentation(.menu)
		default: .none
		}
	}

	private mutating func directionalAction(
		_ direction: Direction,
		modifiers: InputModifiers
	) -> InputReaction {
		if modifiers.contains(.right) { return zoom(direction) }
		if modifiers.contains(.left) { return moveCamera(direction) }
		return moveCursor(direction)
	}

	private mutating func buttonAction(
		_ action: InputAction,
		modifiers: InputModifiers
	) -> InputReaction {
		if modifiers == [.left, .right] { return toggleSettings(action) }
		if modifiers == .right { return setMapMode(action) }
		if modifiers == .left { return .none }

		return switch action {
		case .a: primaryAction()
		case .b: secondaryAction()
		case .c: squareAction()
		case .d: triangleAction()
		}
	}

	private mutating func setMapMode(_ action: InputAction) -> InputReaction {
		switch action {
		case .a: ui.mapMode = .terrain
		case .b: ui.mapMode = ui.mapMode == .country ? .team : .country
		case .c: ui.mapMode = .supply
		case .d: ui.mapMode = .defense
		}
		return .none
	}

	private mutating func toggleSettings(_ action: InputAction) -> InputReaction {
		switch action {
		case .a: break
		case .b: break
		case .c: break
		case .d: ui.autoBattle.toggle()
		}
		return .none
	}

	private mutating func zoom(_ direction: Direction) -> InputReaction {
		switch direction {
		case .up: ui.scale = min(3, ui.scale + 1)
		case .down: ui.scale = max(1, ui.scale - 1)
		case .left, .right: break
		}
		return .none
	}

	private mutating func moveCamera(_ direction: Direction) -> InputReaction {
		ui.camera = ui.camera.diagonal(direction).clamped(tac.map.size)
		return .none
	}

	private mutating func select(_ xy: XY) -> InputReaction {
		guard tac.map.contains(xy) else { return .none }
		ui.cursor = xy
		if tac.player.type == .human { return primaryAction() }
		return .none
	}

	private mutating func moveCursor(_ direction: Direction) -> InputReaction {
		let xy = ui.cursor.neighbor(direction)
		if tac.map.contains(xy) { ui.cursor = xy }
		return .none
	}

	private mutating func primaryAction() -> InputReaction {
		let playerCountry = tac.country
		let playerType = tac[playerCountry].type

		if ui.selectedUnit != .none {
			let unit = tac.units[ui.selectedUnit]
			let unitCountry = unit.country

			if let dst = tac.unitAt(ui.cursor), tac.vision[tac.playerIndex][ui.cursor] {
				if playerType == .human, unitCountry == playerCountry, dst.country.team != unitCountry.team {
					return .action(.attack(ui.selectedUnit, tac.unitsMap[ui.cursor]))
				} else if tac.canEmbark(unit: ui.selectedUnit, transport: tac.unitsMap[ui.cursor]), playerType == .human {
					return .action(.embark(ui.selectedUnit, tac.unitsMap[ui.cursor]))
				} else {
					ui.selectedUnit = dst == unit ? .none : tac.unitsMap[ui.cursor]
				}
			} else if unitCountry == playerCountry, unit.canMove, playerType == .human {
				return .action(.move(ui.selectedUnit, ui.cursor))
			} else if tac.map[ui.cursor].isSettlement, tac.control[ui.cursor] == playerCountry, playerType == .human {
				return .presentation(.shop)
			} else {
				ui.selectedUnit = .none
			}
		} else if tac.vision[tac.playerIndex][ui.cursor], tac.unitAt(ui.cursor) != nil {
			ui.selectedUnit = tac.unitsMap[ui.cursor]
		} else if tac.map[ui.cursor].isSettlement,
			  tac.control[ui.cursor] == playerCountry,
			  playerType == .human {
			return .presentation(.shop)
		}
		return .none
	}

	private mutating func secondaryAction() -> InputReaction {
		ui.selectedUnit = .none
		return .none
	}

	private mutating func squareAction() -> InputReaction {
		guard ui.selectedUnit != .none,
			  tac.canDisembark(unit: ui.selectedUnit, to: ui.cursor),
			  tac[tac.country].type == .human
		else { return .none }
		return .action(.disembark(ui.selectedUnit, ui.cursor))
	}

	private mutating func triangleAction() -> InputReaction {
		guard ui.selectedUnit != .none,
			  tac.canResupply(unit: ui.selectedUnit),
			  tac[tac.country].type == .human
		else { return .none }

		defer { ui.selectedUnit = .none }
		return .action(.resupply(ui.selectedUnit))
	}

	private mutating func prevUnit() -> InputReaction {
		nextUnit(reversed: true)
	}

	private mutating func nextUnit(reversed: Bool = false) -> InputReaction {
		let cnt = tac.units.count
		var idx = ui.selectedUnit != .none ? ui.selectedUnit.index : (reversed ? cnt - 1 : 0)
		let country = tac.country

		for _ in tac.units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = tac.units[i]

			if u.alive, !tac.offMap(unit: i.uid), u.country == country, u.hasActions {
				ui.selectedUnit = i.uid
				ui.cursor = tac.position[i]
				ui.camera = tac.position[i]
				return .none
			}
		}
		ui.selectedUnit = .none
		return .none
	}
}
