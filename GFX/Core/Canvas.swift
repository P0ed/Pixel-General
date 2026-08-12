/// Sprite canvas: the 64 x 32 base diamond sits at the bottom, the rest is headroom.
public struct Canvas: Hashable, Sendable {
	public let width: Int
	public let height: Int

	public init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	/// Unit sprite: 64 x 48, 16 px of headroom.
	public static var unit: Canvas { Canvas(width: 64, height: 48) }

	/// Map tile: 64 x 40, 8 px of headroom — matches `CGSize.tile3D` in PG.
	public static var tile: Canvas { Canvas(width: 64, height: 40) }

	public var count: Int { width * height }

	/// Row the base diamond's top corner falls on.
	public var baseTop: Int { height - Int(Volume.footprint) }

	/// Sprite anchor (y up) that drops the model's footprint centre onto a tile's origin.
	public var anchor: (x: Float, y: Float) { (0.5, Volume.footprint / 2 / Float(height)) }
}

public extension Canvas {

	/// Isometric projection: `x` runs right-and-down, `y` left-and-down, `z` straight up.
	func project(_ p: V3) -> (x: Float, y: Float) {
		(
			Float(width) / 2 + p.x - p.y,
			Float(baseTop) + (p.x + p.y) / 2 - p.z
		)
	}

	/// A world point projecting onto the centre of pixel `(x, y)`; its view ray runs along `(1, 1, 1)`.
	func origin(x: Int, y: Int) -> V3 {
		let sx = Float(x) + 0.5 - Float(width) / 2
		let sy = Float(y) + 0.5 - Float(baseTop)
		return V3(sx / 2, -sx / 2, -sy)
	}

	/// Pixel rect covering a solid's bounding box, clipped to the canvas.
	func rect(of solid: Solid) -> (x: Range<Int>, y: Range<Int>) {
		var minX = Float.greatestFiniteMagnitude
		var minY = Float.greatestFiniteMagnitude
		var maxX = -Float.greatestFiniteMagnitude
		var maxY = -Float.greatestFiniteMagnitude

		for i in 0 ..< 8 {
			let corner = V3(
				i & 1 == 0 ? solid.from.x : solid.to.x,
				i & 2 == 0 ? solid.from.y : solid.to.y,
				i & 4 == 0 ? solid.from.z : solid.to.z
			)
			let p = project(corner)
			minX = min(minX, p.x)
			minY = min(minY, p.y)
			maxX = max(maxX, p.x)
			maxY = max(maxY, p.y)
		}

		return (
			clamp(Int(minX.rounded(.down)), 0, width) ..< clamp(Int(maxX.rounded(.up)) + 1, 0, width),
			clamp(Int(minY.rounded(.down)), 0, height) ..< clamp(Int(maxY.rounded(.up)) + 1, 0, height)
		)
	}
}

private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
	max(lo, min(hi, v))
}
