/// Top-left light: a `.max` toned box shades 255 / 209 / 171 on its top / left / right faces.
public struct Light: Hashable, Sendable {
	public var direction: V3
	public var ambient: Float

	public init(direction: V3 = V3(0.22, 0.37, 0.55), ambient: Float = 0.45) {
		self.direction = direction
		self.ambient = ambient
	}

	public static var topLeft: Light { Light() }
	public static var unit: Light { Light(ambient: 0.25) }

	public func shade(_ normal: V3) -> Float {
		// Keep the horizontal face ramp, then blend towards the roof by the actual tilt.
		// Weighting all three axes by their sum can make a front slope match its side;
		// a raw Lambertian dot product can instead make the slope brighter than the roof.
		let horizontal = abs(normal.x) + abs(normal.y)
		let side = horizontal > 0 ? (normal.x * direction.x + normal.y * direction.y) / horizontal : 0
		let tilt = normal.normalized.z
		let diffuse = side * (1 - abs(tilt)) + direction.z * tilt
		return max(0, min(1, ambient + diffuse))
	}

	public func gray(_ normal: V3, tone: UInt8) -> UInt8 {
		UInt8((Float(tone) * shade(normal)).rounded())
	}
}

public extension Light {

	/// Snaps a gray to `levels` evenly spaced steps; `nil` keeps the full 8-bit ramp.
	static func quantize(_ gray: UInt8, levels: Int?) -> UInt8 {
		guard let levels, levels > 1 else { return gray }
		let step = 255.0 / Float(levels - 1)
		return UInt8((Float(gray) / step).rounded() * step)
	}
}
