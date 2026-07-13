import Foundation
import COR

struct EditorState: ~Copyable {
	var map: Map<32, Terrain>
	var brush: Terrain = .field
	var cursor: XY = .zero
	var camera: XY = .zero
	var scale: Int = 1
}

enum EditorAction {
	case paint(XY, Terrain)
	case setBrush(Terrain)
	case clear
	case randomize
	case save
	case load
	case hq
}

enum EditorEvent {
	case set(XY, Terrain)
	case redraw
	case menu
	case hq
}

extension EditorState {

	init() {
		map = Map(size: 32, zero: .field)
	}

	mutating func apply(_ input: Input) -> InputReaction<EditorAction, EditorEvent> {
		var intent: EditorEvent?
		let action: EditorAction? = switch input {
		case .direction(let direction?, modifiers: let modifiers):
			directionalAction(direction, modifiers: modifiers)
		case .action(.a, modifiers: let modifiers) where !modifiers.contains(.right):
			.paint(cursor, brush)
		case .action(.b, modifiers: let modifiers) where !modifiers.contains(.right):
			cycleBrush(reversed: false)
		case .action(.c, modifiers: _): nil
		case .action(.d, modifiers: _): nil
		case .target(.next): cycleBrush(reversed: false)
		case .target(.prev): cycleBrush(reversed: true)
		case .menu: { intent = .menu; return nil }()
		case .tile(let xy): tileTap(xy)
		case .scale(let value): { scale = value; return nil }()
		case .pan(let dxy): handlePan(dxy)
		default: nil
		}
		if let intent { return .presentation(intent) }
		if let action { return .action(action) }
		return .none
	}

	mutating func reduce(_ action: EditorAction) -> [EditorEvent] {
		var events: [EditorEvent] = []
		switch action {
		case .paint(let xy, let terrain): paint(xy, terrain, into: &events)
		case .setBrush(let terrain): brush = terrain
		case .clear: clearMap(into: &events)
		case .randomize: randomizeMap(into: &events)
		case .save: saveMap()
		case .load: loadMap(into: &events)
		case .hq: events.append(.hq)
		}
		return events
	}

	var status: Status {
		Status(
			text: "\(cursor) \(map[cursor])  brush: \(brush)",
			action: "A: paint  B: brush  ↩ menu"
		)
	}
}

private extension EditorState {

	mutating func directionalAction(
		_ direction: Direction,
		modifiers: InputModifiers
	) -> EditorAction? {
		if modifiers.contains(.right) {
			switch direction {
			case .up: scale = max(1, scale / 2)
			case .down: scale = min(4, scale * 2)
			case .left, .right: break
			}
			return nil
		}
		if modifiers.contains(.left) {
			camera = camera.neighbor(direction).clamped(map.size)
			return nil
		}
		return moveCursor(direction)
	}

	mutating func moveCursor(_ direction: Direction) -> EditorAction? {
		let xy = cursor.neighbor(direction)
		if map.contains(xy) { cursor = xy }
		return nil
	}

	mutating func tileTap(_ xy: XY) -> EditorAction? {
		guard map.contains(xy) else { return nil }
		cursor = xy
		return .paint(xy, brush)
	}

	mutating func handlePan(_ dxy: XY) -> EditorAction? {
		camera = (camera + dxy).clamped(map.size)
		return nil
	}

	func cycleBrush(reversed: Bool) -> EditorAction? {
		let palette = Terrain.palette
		let i = palette.firstIndex(of: brush) ?? 0
		let n = palette.count
		let next = (i + (reversed ? n - 1 : 1)) % n
		return .setBrush(palette[next])
	}

	mutating func paint(_ xy: XY, _ terrain: Terrain, into events: inout [EditorEvent]) {
		guard map.contains(xy), map[xy] != terrain else { return }
		let prev = map[xy]
		map[xy] = terrain

		let touchesWater = terrain.isRiver || prev.isRiver
		let touchesRoad = terrain.hasRoad || prev.hasRoad

		if touchesWater || touchesRoad {
			map.shapeRoads()
			events.append(.redraw)
		} else {
			events.append(.set(xy, terrain))
		}
	}

	mutating func clearMap(into events: inout [EditorEvent]) {
		map.indices.forEach { xy in map[xy] = .field }
		events.append(.redraw)
	}

	mutating func randomizeMap(into events: inout [EditorEvent]) {
		map = Map(size: map.size, seed: Int.random(in: 0 ... .max))
		events.append(.redraw)
	}

	mutating func saveMap() {
		UserDefaults.standard.set(encodeMap(), forKey: "editor.map")
	}

	mutating func loadMap(into events: inout [EditorEvent]) {
		guard let str = UserDefaults.standard.string(forKey: "editor.map") else { return }
		decodeMap(str)
		map.shapeRoads()
		events.append(.redraw)
	}

	func encodeMap() -> String {
		var lines = [] as [String]
		lines.reserveCapacity(map.size)
		for y in (0 ..< map.size).reversed() {
			var row = ""
			row.reserveCapacity(map.size)
			for x in 0 ..< map.size {
				row.append(map[XY(x, y)].code)
			}
			lines.append(row)
		}
		return lines.joined(separator: "\n")
	}

	mutating func decodeMap(_ str: String) {
		map.indices.forEach { xy in map[xy] = .field }
		let lines = str.split(separator: "\n", omittingEmptySubsequences: false)
		for (lineIdx, line) in lines.enumerated() where lineIdx < map.size {
			let y = map.size - 1 - lineIdx
			for (x, ch) in line.enumerated() where x < map.size {
				if let t = Terrain(code: ch) {
					map[XY(x, y)] = t
				}
			}
		}
	}
}

extension Terrain {

	static let palette: [Terrain] = [
		.field, .forest, .hill, .forestHill,
		.mountain, .water, .city,
		.airfield, .roadWE, .bridgeWE, .fort
	]

	var code: Character {
		switch self {
		case .none: "."
		case .field: "F"
		case .forest: "f"
		case .hill: "H"
		case .forestHill: "h"
		case .mountain: "M"
		case .water: "W"
		case .bridgeWE, .bridgeSN: "B"
		case .city: "C"
		case .airfield: "A"
		case .fort: "T"
		case _ where isRoad: "R"
		default: "."
		}
	}

	init?(code: Character) {
		switch code {
		case ".": self = .none
		case "F": self = .field
		case "f": self = .forest
		case "H": self = .hill
		case "h": self = .forestHill
		case "M": self = .mountain
		case "W": self = .water
		case "B": self = .bridgeWE
		case "C": self = .city
		case "A": self = .airfield
		case "T": self = .fort
		case "R": self = .roadWE
		default: return nil
		}
	}
}
