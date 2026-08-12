/// The world volume a sprite is authored in: a 32 x 32 tile footprint, 16 units of headroom.
public enum Volume {
	public static let footprint: Float = 32
	public static let height: Float = 16
	public static var center: V3 { V3(footprint / 2, footprint / 2, 0) }
}

public struct Model: Sendable {
	public var solids: [Solid]

	public init(_ solids: [Solid]) {
		self.solids = solids
	}

	public init(_ solids: Solid...) {
		self.solids = solids
	}
}

public extension Model {

	static func + (a: Model, b: Model) -> Model {
		Model(a.solids + b.solids)
	}

	mutating func add(_ solid: Solid) {
		solids.append(solid)
	}

	func translated(by v: V3) -> Model {
		Model(solids.map { $0.translated(by: v) })
	}

	func rotated(_ turn: Turn, about center: V3 = Volume.center) -> Model {
		Model(solids.map { $0.rotated(turn, about: center) })
	}

	func mirrored(about center: V3 = Volume.center) -> Model {
		Model(solids.map { $0.mirrored(about: center) })
	}

	func toned(_ tone: UInt8) -> Model {
		Model(solids.map { $0.toned(tone) })
	}

	var bounds: (from: V3, to: V3) {
		guard let first = solids.first else { return (.zero, .zero) }
		return solids.dropFirst().reduce((first.from, first.to)) {
			($0.0.min($1.from), $0.1.max($1.to))
		}
	}
}
