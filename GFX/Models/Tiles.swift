public enum Tiles {

	public static let step: Float = 4

	/// Bleed the footprint half a pixel each way so sampling at pixel centres
	/// keeps the full 96 x 48 cell covered, including its four tips.
	private static let near: Float = -0.5 / Canvas.pixelsPerUnit
	private static let far = Volume.footprint - near

	/// Dashed, pixel-width perimeter of the base diamond. Tinting happens downstream.
	public static var cursor: Model {
		let side = Volume.footprint
		let corners = [V3.zero, V3(side, 0, 0), V3(side, side, 0), V3(0, side, 0)]
		let lines = corners.indices.map {
			Line(from: corners[$0], to: corners[($0 + 1) % corners.count], tone: .max, dash: 4)
		}
		let shadows = lines.map {
			var line = $0.translated(by: V3(0, 0, -1 / Canvas.pixelsPerUnit))
			line.tone = 0
			return line
		}
		return Model(lines: shadows + lines)
	}

	public static func base(elevation: Int) -> Model {
		Model(.box(
			from: V3(near, near, 0),
			to: V3(far, far, step * Float(elevation))
		))
	}

	/// Slab climbing from `elevation` to the next level towards `rising`.
	public static func slope(elevation: Int, rising: Direction) -> Model {
		let low = step * Float(elevation)
		return base(elevation: elevation) + Model(.wedge(
			from: V3(near, near, low),
			to: V3(far, far, low + step),
			rising: rising
		))
	}
}
