public enum Tiles {

	public static let step: Float = 4

	/// Pixel centres sample half a unit inside the slab, which would shave the diamond's four
	/// tips; bleeding the footprint half a unit each way keeps the full 64 x 32 cell covered.
	private static let near: Float = -0.5
	private static let far = Volume.footprint + 0.5

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
