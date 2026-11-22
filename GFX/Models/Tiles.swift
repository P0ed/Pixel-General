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

	public static let surface = Renderer.tile.fill(base(elevation: 0))
	public static let grid = Renderer.tile.edges(base(elevation: 0))

	public static let gridHighlight: Bitmap = {
		let canvas = Canvas.tile
		let height = canvas.baseHeight - 2
		var bitmap = Bitmap(canvas: canvas)
		for row in 0 ..< height {
			let left = canvas.width / 2 - 2 - 2 * min(row, height - 1 - row)
			let right = canvas.width - 2 - left
			let y = canvas.baseTop + 1 + row
			let leftTone: UInt8 = (2 * height + 1 - row) % 4 < 2 ? .max : 0
			let rightTone: UInt8 = (row + 2) % 4 < 2 ? .max : 0
			bitmap[left, y] = (leftTone, .max)
			bitmap[left + 1, y] = (leftTone, .max)
			bitmap[right, y] = (rightTone, .max)
			bitmap[right + 1, y] = (rightTone, .max)
		}
		return bitmap
	}()

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
