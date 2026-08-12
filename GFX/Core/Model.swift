/// The world volume a sprite is authored in: a 32 x 32 tile footprint, 16 units of headroom.
public enum Volume {
	public static let footprint: Float = 32
	public static let height: Float = 16
	public static var center: V3 { V3(footprint / 2, footprint / 2, 0) }
}

public struct Model: Sendable {
	public var solids: [Solid]
	public var lines: [Line]

	public init(_ solids: [Solid], lines: [Line] = []) {
		self.solids = solids
		self.lines = lines
	}

	public init(_ solids: Solid...) {
		self.init(solids)
	}

	public init(lines: [Line]) {
		self.init([], lines: lines)
	}
}

public extension Model {

	static func + (a: Model, b: Model) -> Model {
		Model(a.solids + b.solids, lines: a.lines + b.lines)
	}

	mutating func add(_ solid: Solid) {
		solids.append(solid)
	}

	func translated(by v: V3) -> Model {
		mapped { $0.translated(by: v) } lines: { $0.translated(by: v) }
	}

	func rotated(_ turn: Turn, about center: V3 = Volume.center) -> Model {
		mapped { $0.rotated(turn, about: center) } lines: { $0.rotated(turn, about: center) }
	}

	func mirrored(about center: V3 = Volume.center) -> Model {
		mapped { $0.mirrored(about: center) } lines: { $0.mirrored(about: center) }
	}

	/// Strokes keep the gray they were authored with — they are unlit to begin with.
	func toned(_ tone: UInt8) -> Model {
		Model(solids.map { $0.toned(tone) }, lines: lines)
	}

	private func mapped(_ solid: (Solid) -> Solid, lines line: (Line) -> Line) -> Model {
		Model(solids.map(solid), lines: lines.map(line))
	}

	var bounds: (from: V3, to: V3) {
		guard let first = solids.first else { return (.zero, .zero) }
		return solids.dropFirst().reduce((first.from, first.to)) {
			($0.0.min($1.from), $0.1.max($1.to))
		}
	}
}
