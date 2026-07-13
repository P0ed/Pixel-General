import COR

enum StrategicMapMode: UInt8, Hashable {
	case terrain, country, team
}

struct StrategicUI {
	var cursor: XY
	var camera: XY
	var scale: Int
	var mapMode: StrategicMapMode
	var selected: ArmyID?
	var selectable: SetXY?

	init(
		cursor: XY = .zero,
		camera: XY = .zero,
		scale: Int = 1,
		mapMode: StrategicMapMode = .country,
		selected: ArmyID? = nil,
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
		let events = sim.reduce(action)
		if case .endTurn = action { deselect() }
		refreshSelectable()
		return events
	}
}

enum StrategicPresentationIntent {
	case army(Int)
	case menu
}

typealias StrategicInputReaction = InputReaction<StrategicAction, StrategicPresentationIntent>

extension StrategicState {

	mutating func apply(_ input: Input) -> StrategicInputReaction {
		defer { refreshSelectable() }
		return switch input {
		case .direction(let direction?, modifiers: let modifiers):
			directionalAction(direction, modifiers: modifiers)
		case .tile(let xy): select(xy)
		case .action(let action?, modifiers: let modifiers):
			buttonAction(action, modifiers: modifiers)
		case .menu: .presentation(.menu)
		case .target(.prev): selectArmy(reversed: true)
		case .target(.next): selectArmy()
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
		if modifiers.contains(.right) { return setMapMode(action) }
		return switch action {
		case .a: primary(at: ui.cursor)
		case .b: build(at: ui.cursor)
		case .c: army(at: ui.cursor)
		case .d: .none
		}
	}

	private mutating func setMapMode(_ action: InputAction) -> StrategicInputReaction {
		switch action {
		case .a: ui.mapMode = .terrain
		case .b: ui.mapMode = ui.mapMode == .country ? .team : .country
		case .c, .d: break
		}
		return .none
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
		if let selected = ui.selected {
			if sim.army(selected).position == xy {
				deselect()
				return .none
			}
			deselect()
			if selected.country == sim.player.country,
				sim.canAttack(xy, with: selected)
			{
				return .action(.attackFrom(selected.index, xy))
			}
			if selected.country == sim.player.country,
				let cost = sim.marchCost(by: selected.index, to: xy), cost > 0
			{
				return .action(.move(selected.index, xy))
			}
		}
		if let army = sim.army(at: xy) {
			ui.selected = army
			return .none
		}
		return .none
	}

	private mutating func deselect() {
		ui.selected = nil
		ui.selectable = nil
	}

	private mutating func build(at xy: XY) -> StrategicInputReaction {
		if ui.selected != nil {
			deselect()
			return .none
		}
		return sim.canBuild(.fort, at: xy) ? .action(.build(.fort, at: xy)) : .none
	}

	private func army(at xy: XY) -> StrategicInputReaction {
		if let army = sim.army(at: xy), army.country == sim.player.country {
			.presentation(.army(army.index))
		} else if sim.canFound(at: xy) {
			.action(.found(xy))
		} else {
			.none
		}
	}

	private mutating func handlePan(_ dxy: XY) -> StrategicInputReaction {
		ui.camera = (ui.camera + dxy).clamped(sim.owner.size)
		return .none
	}

	private mutating func refreshSelectable() {
		guard let selected = ui.selected,
			sim.armyIsActive(selected.index, for: selected.country)
		else {
			deselect()
			return
		}
		let fieldArmy = sim.army(selected)
		ui.selectable = fieldArmy.mp > 0
			? sim.reachable(by: selected.index, for: selected.country)
			: nil
	}

	private mutating func selectArmy(reversed: Bool = false) -> StrategicInputReaction {
		let country = sim.player.country
		let start = ui.selected?.country == country ? ui.selected!.index : (reversed ? 0 : 3)
		for offset in 1 ... 4 {
			let slot = reversed ? (start - offset + 8) % 4 : (start + offset) % 4
			guard sim.armyIsActive(slot, for: country) else { continue }
			let army = ArmyID(country: country, slot: slot)
			ui.selected = army
			ui.cursor = sim.army(army).position
			return .none
		}
		deselect()
		return .none
	}
}
