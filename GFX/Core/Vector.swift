public struct V3: Hashable, Sendable, BitwiseCopyable {
	public var x: Float
	public var y: Float
	public var z: Float

	public init(_ x: Float, _ y: Float, _ z: Float) {
		self.x = x
		self.y = y
		self.z = z
	}
}

public extension V3 {

	static var zero: V3 { V3(0, 0, 0) }

	static func + (a: V3, b: V3) -> V3 {
		V3(a.x + b.x, a.y + b.y, a.z + b.z)
	}

	static func - (a: V3, b: V3) -> V3 {
		V3(a.x - b.x, a.y - b.y, a.z - b.z)
	}

	static func * (v: V3, s: Float) -> V3 {
		V3(v.x * s, v.y * s, v.z * s)
	}

	static prefix func - (v: V3) -> V3 {
		V3(-v.x, -v.y, -v.z)
	}

	func dot(_ o: V3) -> Float {
		x * o.x + y * o.y + z * o.z
	}

	var length: Float {
		dot(self).squareRoot()
	}

	var normalized: V3 {
		let l = length
		return l > 0 ? self * (1 / l) : self
	}

	func min(_ o: V3) -> V3 {
		V3(Swift.min(x, o.x), Swift.min(y, o.y), Swift.min(z, o.z))
	}

	func max(_ o: V3) -> V3 {
		V3(Swift.max(x, o.x), Swift.max(y, o.y), Swift.max(z, o.z))
	}
}

/// Half-space `n · p <= d`. A convex solid is the intersection of a few of these.
public struct Plane: Hashable, Sendable, BitwiseCopyable {
	public var n: V3
	public var d: Float

	public init(normal: V3, offset: Float) {
		n = normal
		d = offset
	}

	public init(normal: V3, through point: V3) {
		n = normal
		d = normal.dot(point)
	}
}

/// Quarter turn about the vertical axis.
public enum Turn: UInt8, Sendable, CaseIterable {
	case none, right, half, left

	public func apply(_ v: V3) -> V3 {
		switch self {
		case .none: v
		case .right: V3(v.y, -v.x, v.z)
		case .half: V3(-v.x, -v.y, v.z)
		case .left: V3(-v.y, v.x, v.z)
		}
	}
}

public extension Plane {

	func translated(by v: V3) -> Plane {
		Plane(normal: n, offset: d + n.dot(v))
	}

	func rotated(_ turn: Turn, about center: V3) -> Plane {
		let rotated = turn.apply(n)
		return Plane(normal: rotated, offset: d - n.dot(center) + rotated.dot(center))
	}

	/// Reflection across the vertical plane `x = y`, i.e. a horizontal flip on screen.
	func mirrored(about center: V3) -> Plane {
		let swapped = V3(n.y, n.x, n.z)
		return Plane(normal: swapped, offset: d - n.dot(center) + swapped.dot(center))
	}
}
