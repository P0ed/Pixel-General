/// Post-pass darkening: a rim inside the sprite's edge, seams where a part sits behind another.
public struct Outline: Hashable, Sendable {
	public var silhouette: UInt8?
	public var creases: UInt8?
	public var depth: Float

	public init(silhouette: UInt8? = nil, creases: UInt8? = nil, depth: Float = 0.5) {
		self.silhouette = silhouette
		self.creases = creases
		self.depth = depth
	}

	public static var none: Outline { Outline() }

	/// Unit sprites: near-black rim, softer seams between parts.
	public static var unit: Outline { Outline(silhouette: 24, creases: 40) }

	/// Tiles: the 0x64 gray of the hand-drawn `Frame` assets, no seams.
	public static var tile: Outline { Outline(silhouette: 100) }

	/// Settlements: a dark rim plus seams, so neighbouring buildings stay apart.
	public static var building: Outline { Outline(silhouette: 56, creases: 56) }
}

extension Outline {

	func apply(to bitmap: inout Bitmap, depths: [Float], ids: [Int32]) {
		guard silhouette != nil || creases != nil else { return }
		let source = bitmap

		for y in 0 ..< bitmap.height {
			for x in 0 ..< bitmap.width {
				let i = source.index(x: x, y: y)
				guard source.alpha[i] > 0 else { continue }

				var rim = false
				var seam = false

				for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
					let nx = x + dx
					let ny = y + dy
					guard source.contains(x: nx, y: ny) else {
						rim = true
						continue
					}
					let n = source.index(x: nx, y: ny)
					if source.alpha[n] == 0 {
						rim = true
					} else if ids[n] != ids[i], depths[n] > depths[i] + depth {
						seam = true
					}
				}

				if rim, let tone = silhouette {
					bitmap.gray[i] = min(source.gray[i], tone)
				} else if seam, let tone = creases {
					bitmap.gray[i] = min(source.gray[i], tone)
				}
			}
		}
	}
}
