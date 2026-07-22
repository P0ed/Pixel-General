import COR

enum MapMode: UInt8, Hashable {
	case terrain, supply, country, team, defense
}

struct TacticalUI: ~Copyable {
	var cursor: XY = .zero
	var camera: XY = .zero
	var selectedUnit: UID = .none
	var selectable: SetXY?
	var scale: Int = 1
	var mapMode: MapMode = .terrain
}

struct TacticalState: ~Copyable {
	var sim: TacticalSim
	var ui: TacticalUI

	init(sim: consuming TacticalSim, ui: consuming TacticalUI = TacticalUI()) {
		self.sim = sim
		self.ui = ui
	}

	mutating func reduce(_ action: TacticalAction) -> [TacticalEvent] {
		let events = sim.reduce(action)

		switch action {
		case .move(let uid, _), .attack(let uid, _):
			if sim.player.type == .human {
				let keep = sim.units[uid].alive && sim.units[uid].hasActions || sim.cargo[uid] != .none
				ui.selectedUnit = keep ? uid : .none
			}
		case .embark(_, let transport) where sim.player.type == .human:
			ui.selectedUnit = transport
		case .end:
			ui.selectedUnit = .none
		default:
			break
		}

		if sim.player.type != .human, let focus = action.cameraFocus(in: sim) {
			let cam = ui.camera
			let across = (focus.x + focus.y) - (cam.x + cam.y)
			let depth = (focus.y - focus.x) - (cam.y - cam.x)
			if abs(across) > 8 * ui.scale || abs(depth) > 10 * ui.scale {
				ui.camera = focus.clamped(sim.map.size)
			}
		}

		refreshSelectable()
		return events
	}

	private mutating func refreshSelectable() {
		ui.selectable = ui.selectedUnit != .none && sim.units[ui.selectedUnit].canMove
			? sim.moves(for: ui.selectedUnit).setXY : nil
	}
}

private extension TacticalAction {

	func cameraFocus(in sim: borrowing TacticalSim) -> XY? {
		switch self {
		case .move(let uid, _), .embark(let uid, _), .resupply(let uid):
			let xy = sim.position[uid]
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .disembark(_, let xy):
			return sim.isVisibleToHuman(xy) ? xy : nil
		case .attack(let src, let dst):
			let s = sim.position[src], d = sim.position[dst]
			return sim.isVisibleToHuman(s) ? s : sim.isVisibleToHuman(d) ? d : nil
		case .purchase, .takeover, .end:
			return nil
		}
	}
}

enum TacticalPresentationIntent {
	case shop
	case menu
}

typealias TacticalInputReaction = InputReaction<TacticalAction, TacticalPresentationIntent>

extension TacticalState {

	mutating func apply(_ input: Input) -> TacticalInputReaction {
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
		case .pan(let dxy): handlePan(dxy)
		case .menu: .presentation(.menu)
		default: .none
		}
	}

	private mutating func directionalAction(
		_ direction: Direction,
		modifiers: InputModifiers
	) -> TacticalInputReaction {
		if modifiers.contains(.right) { return zoom(direction) }
		if modifiers.contains(.left) { return moveCamera(direction) }
		return moveCursor(direction)
	}

	private mutating func buttonAction(
		_ action: InputAction,
		modifiers: InputModifiers
	) -> TacticalInputReaction {
		if modifiers.contains(.right) { return setMapMode(action) }
		return switch action {
		case .a: primaryAction()
		case .b: secondaryAction()
		case .c: squareAction()
		case .d: triangleAction()
		}
	}

	private mutating func setMapMode(_ action: InputAction) -> TacticalInputReaction {
		switch action {
		case .a: ui.mapMode = .terrain
		case .b: ui.mapMode = ui.mapMode == .country ? .team : .country
		case .c: ui.mapMode = .supply
		case .d: ui.mapMode = .defense
		}
		return .none
	}

	private mutating func zoom(_ direction: Direction) -> TacticalInputReaction {
		switch direction {
		case .up: ui.scale = min(4, ui.scale * 2)
		case .down: ui.scale = max(1, ui.scale / 2)
		case .left, .right: break
		}
		return .none
	}

	private mutating func moveCamera(_ direction: Direction) -> TacticalInputReaction {
		ui.camera = ui.camera.diagonal(direction).clamped(sim.map.size)
		return .none
	}

	private mutating func select(_ xy: XY) -> TacticalInputReaction {
		guard sim.map.contains(xy) else { return .none }
		ui.cursor = xy
		if sim.player.type == .human { return primaryAction() }
		return .none
	}

	private mutating func moveCursor(_ direction: Direction) -> TacticalInputReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.map.contains(xy) { ui.cursor = xy }
		return .none
	}

	private mutating func primaryAction() -> TacticalInputReaction {
		let playerCountry = sim.country
		let playerType = sim[playerCountry].type

		if ui.selectedUnit != .none {
			let unit = sim.units[ui.selectedUnit]
			let unitCountry = unit.country

			if let dst = sim.unitAt(ui.cursor), sim.vision[sim.playerIndex][ui.cursor] {
				if playerType == .human, unitCountry == playerCountry, dst.country.team != unitCountry.team {
					return .action(.attack(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else if sim.canEmbark(unit: ui.selectedUnit, transport: sim.unitsMap[ui.cursor]), playerType == .human {
					return .action(.embark(ui.selectedUnit, sim.unitsMap[ui.cursor]))
				} else {
					ui.selectedUnit = dst == unit ? .none : sim.unitsMap[ui.cursor]
				}
			} else if unitCountry == playerCountry, unit.canMove, playerType == .human {
				return .action(.move(ui.selectedUnit, ui.cursor))
			} else if sim.map[ui.cursor].isSettlement, sim.control[ui.cursor] == playerCountry, playerType == .human {
				return .presentation(.shop)
			} else {
				ui.selectedUnit = .none
			}
		} else if sim.vision[sim.playerIndex][ui.cursor], sim.unitAt(ui.cursor) != nil {
			ui.selectedUnit = sim.unitsMap[ui.cursor]
		} else if sim.map[ui.cursor].isSettlement,
			  sim.control[ui.cursor] == playerCountry,
			  playerType == .human {
			return .presentation(.shop)
		}
		return .none
	}

	private mutating func secondaryAction() -> TacticalInputReaction {
		ui.selectedUnit = .none
		return .none
	}

	private mutating func squareAction() -> TacticalInputReaction {
		guard ui.selectedUnit != .none,
			  sim.canDisembark(unit: ui.selectedUnit, to: ui.cursor),
			  sim[sim.country].type == .human
		else { return .none }
		return .action(.disembark(ui.selectedUnit, ui.cursor))
	}

	private mutating func triangleAction() -> TacticalInputReaction {
		guard ui.selectedUnit != .none,
			  sim.units[ui.selectedUnit].country == sim.country,
			  sim.units[ui.selectedUnit].untouched,
			  sim[sim.country].type == .human
		else { return .none }

		defer { ui.selectedUnit = .none }
		return .action(.resupply(ui.selectedUnit))
	}

	private mutating func prevUnit() -> TacticalInputReaction {
		nextUnit(reversed: true)
	}

	private mutating func nextUnit(reversed: Bool = false) -> TacticalInputReaction {
		let cnt = sim.units.count
		var idx = ui.selectedUnit != .none ? ui.selectedUnit.index : (reversed ? cnt - 1 : 0)
		let country = sim.country

		for _ in sim.units.indices {
			idx += reversed ? -1 : 1
			let i = (cnt + idx) % cnt
			let u = sim.units[i]

			if u.alive, !sim.offMap(unit: i.uid), u.country == country, u.hasActions {
				ui.selectedUnit = i.uid
				ui.cursor = sim.position[i]
				return .none
			}
		}
		ui.selectedUnit = .none
		return .none
	}

	private mutating func handlePan(_ dxy: XY) -> TacticalInputReaction {
		ui.camera = (ui.camera + dxy).clamped(sim.map.size)
		return .none
	}
}
