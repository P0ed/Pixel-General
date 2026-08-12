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
	public static var decal: Renderer { Renderer(canvas: .tile, outline: .decal) }
}

public extension Renderer {

	func render(_ model: Model) -> Bitmap {
		var raster = raster(model)
		outline.apply(to: &raster)
		draw(model.lines, into: &raster)
		return raster.bitmap
	}

	/// The shaded faces alone, for tinting downstream.
	func fill(_ model: Model) -> Bitmap {
		var raster = raster(model)
		draw(model.lines, into: &raster)
		return raster.bitmap
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

	/// Strokes go on last, depth-tested against the solids but never outlined: a line
	/// thin enough to be all rim would otherwise come out solid black.
	func draw(_ lines: [Line], into raster: inout Raster) {
		for (index, line) in lines.enumerated() {
			// Solids own 0...; -1 is empty, so strokes count down from -2.
			let id = Int32(-2 - index)
			for pixel in line.trace(on: canvas) {
				let i = raster.bitmap.index(x: pixel.x, y: pixel.y)
				// A stroke lying on a face lands up to a third of a unit behind the depth
				// sampled at the pixel centre, so ties have to go to the stroke.
				guard pixel.t >= raster.depths[i] - 0.5 else { continue }

				raster.depths[i] = pixel.t
				raster.ids[i] = id
				raster.faces[i] = -1
				raster.bitmap.gray[i] = Light.quantize(line.tone, levels: levels)
				raster.bitmap.alpha[i] = .max
			}
		}
	}
}
