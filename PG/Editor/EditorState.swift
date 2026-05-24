import Foundation

struct EditorState: ~Copyable {
	var map: Map<Terrain>
	var brush: Terrain = .field
	var cursor: XY = .zero
	var camera: XY = .zero
	var scale: Int = 1
	var events: CArray<32, EditorEvent> = .init(tail: .menu)
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

	mutating func apply(_ input: Input) -> EditorAction? {
		switch input {
		case .direction(let direction?): moveCursor(direction)
		case .action(.a): .paint(cursor, brush)
		case .action(.b): cycleBrush(reversed: false)
		case .action(.c): nil
		case .action(.d): nil
		case .target(.next): cycleBrush(reversed: false)
		case .target(.prev): cycleBrush(reversed: true)
		case .menu: { events.add(.menu); return nil }()
		case .tile(let xy): tileTap(xy)
		case .scale(let value): { scale = value; return nil }()
		case .pan(let dxy): handlePan(dxy)
		default: nil
		}
	}

	mutating func reduce(_ action: EditorAction?) -> [EditorEvent] {
		switch action {
		case .paint(let xy, let terrain): paint(xy, terrain)
		case .setBrush(let terrain): brush = terrain
		case .clear: clearMap()
		case .randomize: randomizeMap()
		case .save: saveMap()
		case .load: loadMap()
		case .hq: events.add(.hq)
		case .none: break
		}
		defer { events.erase() }
		return events.map { _, e in e }
	}

	var status: Status {
		Status(
			text: "\(cursor) \(map[cursor])  brush: \(brush)",
			action: .init("A: paint  B: brush  ↩ menu")
		)
	}
}

private extension EditorState {

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
		cursor = (cursor + dxy).clamped(map.size)
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

	mutating func paint(_ xy: XY, _ terrain: Terrain) {
		guard map.contains(xy), map[xy] != terrain else { return }
		let prev = map[xy]
		map[xy] = terrain

		let touchesWater = terrain.isRiver || prev.isRiver
		let touchesRoad = terrain.hasRoad || prev.hasRoad

		if touchesWater || touchesRoad {
			map.shapeRoads()
			events.add(.redraw)
		} else {
			events.add(.set(xy, terrain))
		}
	}

	mutating func clearMap() {
		map.indices.forEach { xy in map[xy] = .field }
		events.add(.redraw)
	}

	mutating func randomizeMap() {
		map = Map(size: map.size, seed: Int.random(in: 0 ... .max))
		events.add(.redraw)
	}

	mutating func saveMap() {
		UserDefaults.standard.set(encodeMap(), forKey: "editor.map")
	}

	mutating func loadMap() {
		guard let str = UserDefaults.standard.string(forKey: "editor.map") else { return }
		decodeMap(str)
		map.shapeRoads()
		events.add(.redraw)
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
		.airfield, .roadWE, .bridgeWE
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
		case "R": self = .roadWE
		default: return nil
		}
	}

	var imageName: String {
		switch self {
		case .field: "Field"
		case .forest: "Forest"
		case .hill: "Hill"
		case .forestHill: "ForestHill"
		case .mountain: "Mountain"
		case .water: "Water"
		case .bridgeWE: "Bridge-WE"
		case .bridgeSN: "Bridge-SN"
		case .city: "City"
		case .airfield: "Airfield"
		case .roadNW: "Road-nw"
		case .roadNE: "Road-ne"
		case .roadWE: "Road-we"
		case .roadSN: "Road-sn"
		case .roadSW: "Road-sw"
		case .roadSE: "Road-se"
		case .villageE: "Village-E"
		case .villageN: "Village-N"
		case .villageW: "Village-W"
		case .villageS: "Village-S"
		case .roadX: "Road-nwse"
		case .none: "Clear"
		}
	}
}
