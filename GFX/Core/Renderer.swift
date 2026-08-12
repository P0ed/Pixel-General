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
		var raster = raster(model)
		outline.apply(to: &raster)
		return raster.bitmap
	}

	/// The shaded faces alone, for tinting downstream.
	func fill(_ model: Model) -> Bitmap {
		raster(model).bitmap
	}

	/// The outline alone, for drawing over an independently tinted fill.
	func edges(_ model: Model) -> Bitmap {
		var raster = raster(model)
		outline.apply(to: &raster)

		var edges = Bitmap(canvas: canvas)
		for i in 0 ..< canvas.count where raster.outlined[i] {
			edges.gray[i] = raster.bitmap.gray[i]
			edges.alpha[i] = .max
		}
		return edges
	}
}

extension Renderer {

	struct Raster {
		var bitmap: Bitmap
		var depths: [Float]
		var ids: [Int32]
		var faces: [Int32]
		var outlined: [Bool]
	}

	func raster(_ model: Model) -> Raster {
		var raster = Raster(
			bitmap: Bitmap(canvas: canvas),
			depths: [Float](repeating: -.greatestFiniteMagnitude, count: canvas.count),
			ids: [Int32](repeating: -1, count: canvas.count),
			faces: [Int32](repeating: -1, count: canvas.count),
			outlined: [Bool](repeating: false, count: canvas.count)
		)

		for (id, solid) in model.solids.enumerated() {
			let rect = canvas.rect(of: solid)
			for y in rect.y {
				for x in rect.x {
					guard let hit = solid.hit(canvas.origin(x: x, y: y)) else { continue }
					let i = raster.bitmap.index(x: x, y: y)
					guard hit.t > raster.depths[i] else { continue }

					raster.depths[i] = hit.t
					raster.ids[i] = Int32(id)
					raster.faces[i] = Int32(hit.face)
					raster.bitmap.gray[i] = Light.quantize(light.gray(hit.normal, tone: solid.tone), levels: levels)
					raster.bitmap.alpha[i] = .max
				}
			}
		}

		return raster
	}
}
