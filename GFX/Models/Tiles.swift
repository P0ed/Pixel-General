public enum Tiles {

	public static let step: Float = 6

	/// Bleed the footprint half a pixel each way so sampling at pixel centres
	/// keeps the full 96 x 48 cell covered, including its four tips.
	private static let near: Float = -0.5
	private static let far = Volume.footprint - near
	private static let tileInterior = interiorPixels(on: .tile)

	static func interior(on canvas: Canvas) -> [Bool] {
		canvas == .tile ? tileInterior : interiorPixels(on: canvas)
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

	public static var mountain: Model {
		let snowline: Float = 16
		var rock = Solid.pyramid(from: V3(7, 8, 0), to: V3(35, 36, 24), tone: 164)
		var snow = rock.toned(248)
		// Split the highest peak at the snowline so the two parts share the same slopes.
		rock.to.z = snowline
		rock.planes.append(Plane(normal: V3(0, 0, 1), offset: snowline))
		snow.from.z = snowline
		snow.planes.append(Plane(normal: V3(0, 0, -1), offset: -snowline))

		return Model([
			rock, snow,
			.pyramid(from: V3(7, 20, 0), to: V3(25, 46, 18), tone: 153),
			.pyramid(from: V3(24, 7, 0), to: V3(46, 26, 17), tone: 145),
		])
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
