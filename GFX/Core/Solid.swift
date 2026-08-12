/// Horizontal direction. `xPlus` runs right-and-down on screen, `yPlus` left-and-down.
public enum Direction: UInt8, Sendable, CaseIterable {
	case xPlus, xMinus, yPlus, yMinus

	public var axis: Axis {
		switch self {
		case .xPlus, .xMinus: .x
		case .yPlus, .yMinus: .y
		}
	}
}

public enum Axis: UInt8, Sendable, CaseIterable {
	case x, y
}

/// Convex solid: the intersection of its half-spaces, bounded by `from ... to`.
public struct Solid: Sendable {
	public var planes: [Plane]
	public var from: V3
	public var to: V3
	public var tone: UInt8

	public init(planes: [Plane], from: V3, to: V3, tone: UInt8 = .max) {
		self.planes = planes
		self.from = from
		self.to = to
		self.tone = tone
	}
}

public extension Solid {

	static func box(from: V3, to: V3, tone: UInt8 = .max) -> Solid {
		Solid(planes: bounds(from: from, to: to), from: from, to: to, tone: tone)
	}

	/// Box with its top sheared into a ramp climbing from `from.z` to `to.z` towards `rising`.
	static func wedge(from: V3, to: V3, rising: Direction, tone: UInt8 = .max) -> Solid {
		let size = to - from
		let height = size.z
		let run = rising.axis == .x ? size.x : size.y
		let slope: Plane

		switch rising {
		case .xPlus: slope = Plane(normal: V3(-height, 0, run), through: from)
		case .xMinus: slope = Plane(normal: V3(height, 0, run), through: V3(to.x, from.y, from.z))
		case .yPlus: slope = Plane(normal: V3(0, -height, run), through: from)
		case .yMinus: slope = Plane(normal: V3(0, height, run), through: V3(from.x, to.y, from.z))
		}

		var planes = bounds(from: from, to: to)
		planes.removeFirst() // the +z cap, replaced by the slope
		planes.append(slope)

		return Solid(planes: planes, from: from, to: to, tone: tone)
	}

	/// Triangular prism: a roof whose ridge runs along `ridge` at `to.z`, eaves at `from.z`.
	static func gable(from: V3, to: V3, ridge: Axis, tone: UInt8 = .max) -> Solid {
		let size = to - from
		let height = size.z
		let run = (ridge == .x ? size.y : size.x) / 2
		var planes = bounds(from: from, to: to)
		planes.removeFirst()

		switch ridge {
		case .x:
			planes.append(Plane(normal: V3(0, -height, run), through: from))
			planes.append(Plane(normal: V3(0, height, run), through: V3(from.x, to.y, from.z)))
		case .y:
			planes.append(Plane(normal: V3(-height, 0, run), through: from))
			planes.append(Plane(normal: V3(height, 0, run), through: V3(to.x, from.y, from.z)))
		}

		return Solid(planes: planes, from: from, to: to, tone: tone)
	}

	static func pyramid(from: V3, to: V3, tone: UInt8 = .max) -> Solid {
		let size = to - from
		let height = size.z
		let mid = (from + to) * 0.5
		let apex = V3(mid.x, mid.y, to.z)
		var planes = bounds(from: from, to: to)
		planes.removeFirst()

		planes.append(Plane(normal: V3(-height, 0, size.x / 2), through: apex))
		planes.append(Plane(normal: V3(height, 0, size.x / 2), through: apex))
		planes.append(Plane(normal: V3(0, -height, size.y / 2), through: apex))
		planes.append(Plane(normal: V3(0, height, size.y / 2), through: apex))

		return Solid(planes: planes, from: from, to: to, tone: tone)
	}

	/// The six axis-aligned faces, `+z` first so the shaping constructors can drop it.
	private static func bounds(from: V3, to: V3) -> [Plane] {
		[
			Plane(normal: V3(0, 0, 1), offset: to.z),
			Plane(normal: V3(0, 0, -1), offset: -from.z),
			Plane(normal: V3(1, 0, 0), offset: to.x),
			Plane(normal: V3(-1, 0, 0), offset: -from.x),
			Plane(normal: V3(0, 1, 0), offset: to.y),
			Plane(normal: V3(0, -1, 0), offset: -from.y),
		]
	}
}

public extension Solid {

	func translated(by v: V3) -> Solid {
		Solid(planes: planes.map { $0.translated(by: v) }, from: from + v, to: to + v, tone: tone)
	}

	func rotated(_ turn: Turn, about center: V3) -> Solid {
		let a = turn.apply(from - center) + center
		let b = turn.apply(to - center) + center
		return Solid(
			planes: planes.map { $0.rotated(turn, about: center) },
			from: a.min(b),
			to: a.max(b),
			tone: tone
		)
	}

	func mirrored(about center: V3) -> Solid {
		let a = V3(from.y - center.y + center.x, from.x - center.x + center.y, from.z)
		let b = V3(to.y - center.y + center.x, to.x - center.x + center.y, to.z)
		return Solid(
			planes: planes.map { $0.mirrored(about: center) },
			from: a.min(b),
			to: a.max(b),
			tone: tone
		)
	}

	func toned(_ tone: UInt8) -> Solid {
		Solid(planes: planes, from: from, to: to, tone: tone)
	}

	func contains(_ p: V3) -> Bool {
		planes.allSatisfy { $0.n.dot(p) <= $0.d + 1e-4 }
	}

	/// Nearest surface along the view ray `p0 + t * (1,1,1)`; larger `t` is nearer the camera.
	func hit(_ p0: V3) -> (t: Float, normal: V3, face: Int)? {
		var near = -Float.greatestFiniteMagnitude
		var far = Float.greatestFiniteMagnitude
		var normal = V3.zero
		var face = 0

		for (index, plane) in planes.enumerated() {
			let denom = plane.n.x + plane.n.y + plane.n.z
			let num = plane.d - plane.n.dot(p0)

			guard abs(denom) > 1e-6 else {
				if num < 0 { return nil }
				continue
			}
			let t = num / denom
			if denom > 0 {
				if t < far {
					far = t
					normal = plane.n
					face = index
				}
			} else if t > near {
				near = t
			}
		}

		return near <= far ? (far, normal, face) : nil
	}
}
