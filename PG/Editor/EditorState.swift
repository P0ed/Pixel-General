struct EditorState: ~Copyable {
	var map: Map<Terrain>
	var brush: Terrain = .field
	var cursor: XY = .zero
	var camera: XY = .zero
	var scale: Int = 1
	var events: CArray<32, EditorEvent> = .init(tail: .menu)
}

enum EditorAction: Hashable {
	case paint(XY, Terrain)
	case setBrush(Terrain)
	case clear
	case randomize
}

enum EditorEvent {
	case set(XY, Terrain)
	case redraw
	case menu
}

extension EditorState {

	init() {
		map = Map(size: 32, zero: .field)
		cursor = XY(map.size / 2, map.size / 2)
		camera = cursor
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
		map[xy] = terrain
		events.add(.set(xy, terrain))
	}

	mutating func clearMap() {
		map.indices.forEach { xy in map[xy] = .field }
		events.add(.redraw)
	}

	mutating func randomizeMap() {
		map = Map(size: map.size, seed: Int.random(in: 0 ... .max))
		events.add(.redraw)
	}
}

extension Terrain {

	static let palette: [Terrain] = [
		.field, .forest, .hill, .forestHill, .mountain,
		.water, .river00, .city, .airfield, .roadNWSE
	]

	var imageName: String {
		switch self {
		case .field: "Field"
		case .forest: "Forest"
		case .hill: "Hill"
		case .forestHill: "ForestHill"
		case .mountain: "Mountain"
		case .water: "Water"
		case .river00, .river01, .river10, .river11: "River00"
		case .bridge01: "Bridge01"
		case .bridge10: "Bridge10"
		case .city: "City"
		case .airfield: "Airfield"
		case .roadNW: "Road-nw"
		case .roadNE: "Road-ne"
		case .roadWE: "Road-we"
		case .roadSN: "Road-sn"
		case .roadSW: "Road-sw"
		case .roadSE: "Road-se"
		case .roadNWE: "Road-nwe"
		case .roadSWE: "Road-swe"
		case .roadSEN: "Road-sen"
		case .roadSWN: "Road-swn"
		case .roadNWSE: "Road-nwse"
		case .none: "Clear"
		}
	}
}
