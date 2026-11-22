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

	private enum GridEdge: CaseIterable {
		case topLeft, topRight, bottomLeft, bottomRight

		var isUpper: Bool { self == .topLeft || self == .topRight }

		func contains(_ point: V3) -> Bool {
			let x = point.x - point.z
			let y = point.y - point.z
			return switch self {
			case .topLeft: x < 1
			case .topRight: y < 1
			case .bottomLeft: y > Volume.footprint - 1
			case .bottomRight: x > Volume.footprint - 1
			}
		}
	}

	private static let gridOutline = Renderer.tile.edges(footprint)
	private static let gridPixels = Dictionary(uniqueKeysWithValues: GridEdge.allCases.map { edge in
		let canvas = Canvas.tile
		let pixels = gridOutline.alpha.indices.filter { i in
			gridOutline.alpha[i] > 0 && edge.contains(canvas.origin(x: i % canvas.width, y: i / canvas.width))
		}
		return (edge, pixels)
	})

	/// Draws the two lower edges inside the tile so each shared line has one owner.
	/// The upper edges close the grid along the outer boundary of the map.
	public static func grid(topLeft: Bool = false, topRight: Bool = false) -> Bitmap {
		var bitmap = Bitmap(canvas: .tile)
		func draw(_ edge: GridEdge) {
			for i in gridPixels[edge]! {
				bitmap.gray[i] = gridOutline.gray[i]
				bitmap.alpha[i] = gridOutline.alpha[i]
			}
		}
		draw(.bottomLeft)
		draw(.bottomRight)
		if topLeft { draw(.topLeft) }
		if topRight { draw(.topRight) }
		return bitmap
	}

	public static func gridHighlight(topLeft: Bool, topRight: Bool) -> Bitmap {
		let canvas = Canvas.tile
		let halfWidth = canvas.width / 2
		let halfHeight = canvas.baseHeight / 2
		let topRow = canvas.baseTop - 1
		var bitmap = Bitmap(width: canvas.width + 2, height: canvas.height)
		func mark(x: Int, y: Int, distanceFromTop: Int) {
			let step = x < halfWidth ? 4 * halfHeight - distanceFromTop : distanceFromTop
			bitmap[x + 1, y] = (step % 4 < 2 ? .max : 0, .max)
		}
		func draw(_ edge: GridEdge, offsetX: Int = 0, offsetY: Int = 0) {
			for i in gridPixels[edge]! {
				let x = i % canvas.width + offsetX
				let y = i / canvas.width + offsetY
				let distanceFromTop = y - topRow - (edge.isUpper ? 1 : 0)
				mark(x: x, y: y, distanceFromTop: distanceFromTop)
			}
		}
		draw(.bottomLeft)
		draw(.bottomRight)
		if topLeft {
			draw(.topLeft)
		} else {
			draw(.bottomRight, offsetX: -halfWidth, offsetY: -halfHeight)
		}
		if topRight {
			draw(.topRight)
		} else {
			draw(.bottomLeft, offsetX: halfWidth, offsetY: -halfHeight)
		}
		if !topLeft && !topRight {
			mark(x: halfWidth - 1, y: topRow, distanceFromTop: 0)
			mark(x: halfWidth, y: topRow, distanceFromTop: 0)
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
