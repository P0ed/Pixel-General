public enum Tiles {

	public enum Variant: Int, CaseIterable, Sendable {
		case first, second, third, fourth
	}

	public static let step: Float = 6

	/// Bleed the footprint half a pixel each way so sampling at pixel centres
	/// keeps the full 96 x 48 cell covered, including its four tips.
	private static let near: Float = -0.5
	private static let far = Volume.footprint - near
	private static let tileInterior = interiorPixels(on: .tile)
	private static let tileFootprint = footprintPixels(on: .tile)

	/// A flat tile diamond. Adjacent footprints meet without overlapping.
	public static var footprint: Model {
		let side = Volume.footprint
		return Model(.box(from: .zero, to: V3(side, side, 0)))
	}

	/// Draws the two lower edges inside the tile so each shared line has one owner.
	/// The upper edges close the grid along the outer boundary of the map.
	public static func grid(topLeft: Bool = false, topRight: Bool = false) -> Bitmap {
		let canvas = Canvas.tile
		var outline = Renderer.tile.edges(footprint)
		for i in outline.alpha.indices where outline.alpha[i] > 0 {
			let origin = canvas.origin(x: i % canvas.width, y: i / canvas.width)
			let x = origin.x - origin.z
			let y = origin.y - origin.z
			if x > Volume.footprint - 1 || y > Volume.footprint - 1 { continue }
			if (topLeft && x < 1) || (topRight && y < 1) { continue }
			outline.alpha[i] = 0
		}
		return outline
	}

	static func interior(on canvas: Canvas) -> [Bool] {
		canvas == .tile ? tileInterior : interiorPixels(on: canvas)
	}

	static func footprintMask(on canvas: Canvas) -> [Bool] {
		canvas == .tile ? tileFootprint : footprintPixels(on: canvas)
	}

	private static func footprintPixels(on canvas: Canvas) -> [Bool] {
		Renderer(canvas: canvas, outline: .none).fill(footprint).alpha.map { $0 > 0 }
	}

	private static func interiorPixels(on canvas: Canvas) -> [Bool] {
		let model = base(elevation: 0)
		let renderer = Renderer(canvas: canvas, outline: .tile)
		return zip(renderer.fill(model).alpha, renderer.edges(model).alpha).map { $0 > 0 && $1 == 0 }
	}

	/// Dashed, pixel-width perimeter of the base diamond. Tinting happens downstream.
	public static var cursor: Model {
		let side = Volume.footprint
		let corners = [V3.zero, V3(side, 0, 0), V3(side, side, 0), V3(0, side, 0)]
		let lines = corners.indices.map {
			Line(from: corners[$0], to: corners[($0 + 1) % corners.count], tone: .max, dash: 6)
		}
		let shadows = lines.map {
			var line = $0.translated(by: V3(0, 0, -1))
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
