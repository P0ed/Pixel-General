public enum Tiles {

	public static let step: Float = 4

	public static func base(elevation: Int) -> Model {
		Model(.box(
			from: .zero,
			to: V3(Volume.footprint, Volume.footprint, step * Float(elevation))
		))
	}

	/// Slab climbing from `elevation` to the next level towards `rising`.
	public static func slope(elevation: Int, rising: Direction) -> Model {
		let low = step * Float(elevation)
		let side = Volume.footprint
		return base(elevation: elevation) + Model(.wedge(
			from: V3(0, 0, low),
			to: V3(side, side, low + step),
			rising: rising
		))
	}
}
