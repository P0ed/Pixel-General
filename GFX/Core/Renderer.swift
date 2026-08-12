public struct Renderer: Sendable {
	public var canvas: Canvas
	public var light: Light
	public var outline: Outline
	public var levels: Int?

	public init(
		canvas: Canvas = .unit,
		light: Light = .topLeft,
		outline: Outline = .unit,
		levels: Int? = nil
	) {
		self.canvas = canvas
		self.light = light
		self.outline = outline
		self.levels = levels
	}

	public static var unit: Renderer { Renderer() }
	public static var tile: Renderer { Renderer(canvas: .tile, outline: .tile) }
	public static var building: Renderer { Renderer(canvas: .tile, outline: .building) }
}

public extension Renderer {

	func render(_ model: Model) -> Bitmap {
		var bitmap = Bitmap(canvas: canvas)
		var depths = [Float](repeating: -.greatestFiniteMagnitude, count: canvas.count)
		var ids = [Int32](repeating: -1, count: canvas.count)

		for (id, solid) in model.solids.enumerated() {
			let rect = canvas.rect(of: solid)
			for y in rect.y {
				for x in rect.x {
					guard let hit = solid.hit(canvas.origin(x: x, y: y)) else { continue }
					let i = bitmap.index(x: x, y: y)
					guard hit.t > depths[i] else { continue }

					depths[i] = hit.t
					ids[i] = Int32(id)
					bitmap.gray[i] = Light.quantize(light.gray(hit.normal, tone: solid.tone), levels: levels)
					bitmap.alpha[i] = .max
				}
			}
		}

		outline.apply(to: &bitmap, depths: depths, ids: ids)

		return bitmap
	}
}
