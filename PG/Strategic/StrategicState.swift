import COR

enum StrategicMapMode: UInt8, Hashable {
	case country, team
}

struct StrategicUI {
	var cursor: XY
	var camera: XY
	var scale: Int
	var mapMode: StrategicMapMode
	var selected: Int?
	var selectable: SetXY?

	init(
		cursor: XY = .zero,
		camera: XY = .zero,
		scale: Int = 1,
		mapMode: StrategicMapMode = .country,
		selected: Int? = nil,
		selectable: SetXY? = nil
	) {
		self.cursor = cursor
		self.camera = camera
		self.scale = scale
		self.mapMode = mapMode
		self.selected = selected
		self.selectable = selectable
	}
}

struct StrategicState: ~Copyable {
	var sim: StrategicSim
	var ui: StrategicUI

	init(sim: consuming StrategicSim, ui: StrategicUI = StrategicUI()) {
		self.sim = sim
		self.ui = ui
	}

	mutating func reduce(_ action: StrategicAction) -> [StrategicEvent] {
		sim.reduce(action)
	}
}

enum StrategicPresentationIntent {
	case army(Int)
	case menu
}

typealias StrategicInputReaction = InputReaction<StrategicAction, StrategicPresentationIntent>

extension StrategicState {

	mutating func apply(_ input: Input) -> StrategicInputReaction {
		switch input {
		case .direction(let direction?, modifiers: let modifiers):
			directionalAction(direction, modifiers: modifiers)
		case .tile(let xy): select(xy)
		case .action(let action?, modifiers: let modifiers):
			buttonAction(action, modifiers: modifiers)
		case .menu: .presentation(.menu)
		case .mode: toggleMapMode()
		case .scale(let value): { ui.scale = value; return .none }()
		case .pan(let dxy): handlePan(dxy)
		default: .none
		}
	}

	private mutating func directionalAction(
		_ direction: Direction,
		modifiers: InputModifiers
	) -> StrategicInputReaction {
		if modifiers.contains(.right) { return zoom(direction) }
		if modifiers.contains(.left) { return moveCamera(direction) }
		return moveCursor(direction)
	}

	private mutating func buttonAction(
		_ action: InputAction,
		modifiers: InputModifiers
	) -> StrategicInputReaction {
		if modifiers.contains(.right) {
			return switch action {
			case .b: toggleMapMode()
			case .a, .c, .d: .none
			}
		}
		return switch action {
		case .a: primary(at: ui.cursor)
		case .b: build(at: ui.cursor)
		case .c: army(at: ui.cursor)
		case .d: .none
		}
	}

	private mutating func zoom(_ direction: Direction) -> StrategicInputReaction {
		switch direction {
		case .up: ui.scale = max(1, ui.scale / 2)
		case .down: ui.scale = min(4, ui.scale * 2)
		case .left, .right: break
		}
		return .none
	}

	private mutating func moveCamera(_ direction: Direction) -> StrategicInputReaction {
		ui.camera = ui.camera.neighbor(direction).clamped(sim.owner.size)
		return .none
	}

	private mutating func moveCursor(_ direction: Direction) -> StrategicInputReaction {
		let xy = ui.cursor.neighbor(direction)
		if sim.owner.contains(xy) { ui.cursor = xy }
		return .none
	}

	private mutating func select(_ xy: XY) -> StrategicInputReaction {
		guard sim.owner.contains(xy) else { return .none }
		ui.cursor = xy
		return primary(at: xy)
	}

	private mutating func primary(at xy: XY) -> StrategicInputReaction {
		if let slot = ui.selected {
			deselect()
			if let cost = sim.marchCost(by: slot, to: xy), cost > 0 {
				return .action(.move(slot, xy))
			}
		}
		if let slot = sim.armyIndex(at: xy) {
			ui.selected = slot
			ui.selectable = sim.reachable(by: slot)
			return .none
		}
		return sim.canAttack(xy) ? .action(.attack(xy)) : .none
	}

	private mutating func deselect() {
		ui.selected = nil
		ui.selectable = nil
	}

	private func build(at xy: XY) -> StrategicInputReaction {
		sim.canBuild(.fort, at: xy) ? .action(.build(.fort, at: xy)) : .none
	}

	private func army(at xy: XY) -> StrategicInputReaction {
		if let slot = sim.armyIndex(at: xy) {
			.presentation(.army(slot))
		} else if sim.canFound(at: xy) {
			.action(.found(xy))
		} else {
			.none
		}
	}

	private mutating func toggleMapMode() -> StrategicInputReaction {
		ui.mapMode = ui.mapMode == .team ? .country : .team
		return .none
	}

	private mutating func handlePan(_ dxy: XY) -> StrategicInputReaction {
		ui.camera = (ui.camera + dxy).clamped(sim.owner.size)
		return .none
	}
}
