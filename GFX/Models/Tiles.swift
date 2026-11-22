public enum Tiles {

	public enum Variant: Int, CaseIterable, Sendable {
		case first, second, third, fourth
	}

	public static let step: Float = 6

	/// Bleed the footprint half a pixel each way so sampling at pixel centres
	/// keeps the full 96 x 48 cell covered, including its four tips.
	private static let near: Float = -0.5
	private static let far = Volume.footprint - near
	private static let tileFootprint = footprintPixels(on: .tile)

	/// A flat tile diamond. Adjacent footprints meet without overlapping.
	public static var footprint: Model {
		let side = Volume.footprint
		return Model(.box(from: .zero, to: V3(side, side, 0)))
	}

	/// Draws the two lower edges inside the tile so each shared line has one owner.
	/// The upper edges close the grid along the outer boundary of the map.
	public static func grid(topLeft: Bool = false, topRight: Bool = false) -> Bitmap {
		let gray = Outline.tile.silhouette!
		return gridOutline(topLeft: topLeft, topRight: topRight) { _ in gray }
	}

	public static let gridHighlight = gridOutline(topLeft: true, topRight: true) { step in
		step % 4 < 2 ? .max : 0
	}

	private static func gridOutline(topLeft: Bool, topRight: Bool, tone: (Int) -> UInt8) -> Bitmap {
		let canvas = Canvas.tile
		let halfHeight = canvas.baseHeight / 2
		let topRow = canvas.baseTop - 1
		var bitmap = Bitmap(width: canvas.width + 2, height: canvas.height)
		func drawStep(x: Int, y: Int, step: Int) {
			let gray = tone(step)
			bitmap[x, y] = (gray, .max)
			bitmap[x + 1, y] = (gray, .max)
		}
		for row in 0 ... canvas.baseHeight {
			let left = 2 * abs(row - halfHeight)
			let y = topRow + row
			if row > halfHeight || topLeft {
				drawStep(x: left, y: y, step: 2 * canvas.baseHeight - row)
			}
			if row > halfHeight || topRight {
				drawStep(x: canvas.width - left, y: y, step: row)
			}
		}
		return bitmap
	}

	static func footprintMask(on canvas: Canvas) -> [Bool] {
		canvas == .tile ? tileFootprint : footprintPixels(on: canvas)
	}

	private static func footprintPixels(on canvas: Canvas) -> [Bool] {
		Renderer(canvas: canvas, outline: .none).fill(footprint).alpha.map { $0 > 0 }
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
