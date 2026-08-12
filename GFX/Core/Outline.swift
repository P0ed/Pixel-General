/// Post-pass darkening: a rim inside the sprite's edge, seams where a part sits behind
/// another, and creases where one solid's own faces meet.
public struct Outline: Hashable, Sendable {
	public var silhouette: UInt8?
	public var creases: UInt8?
	public var faces: UInt8?
	public var depth: Float

	public init(silhouette: UInt8? = nil, creases: UInt8? = nil, faces: UInt8? = nil, depth: Float = 0.5) {
		self.silhouette = silhouette
		self.creases = creases
		self.faces = faces
		self.depth = depth
	}

	public static var none: Outline { Outline() }

	/// Unit sprites: near-black rim, softer seams between parts.
	public static var unit: Outline { Outline(silhouette: 24, creases: 40) }

	/// Tiles: the 0x64 gray of the hand-drawn `Frame` assets, along every edge.
	public static var tile: Outline { Outline(silhouette: 100, faces: 100) }

	/// Settlements: a dark rim plus seams, so neighbouring buildings stay apart.
	public static var building: Outline { Outline(silhouette: 56, creases: 56) }
}

extension Outline {

	func apply(to raster: inout Renderer.Raster) {
		guard silhouette != nil || creases != nil || faces != nil else { return }
		let source = raster.bitmap

		for y in 0 ..< source.height {
			for x in 0 ..< source.width {
				let i = source.index(x: x, y: y)
				guard source.alpha[i] > 0 else { continue }

				var rim = false
				var seam = false
				var crease = false

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
					} else if raster.ids[n] != raster.ids[i] {
						seam = seam || raster.depths[n] > raster.depths[i] + depth
					} else if raster.faces[n] != raster.faces[i] {
						// Only the darker side of the crease takes the line, so it stays 1 face thick.
						crease = crease || source.gray[i] < source.gray[n]
							|| (source.gray[i] == source.gray[n] && raster.faces[i] > raster.faces[n])
					}
				}

				let tone = rim ? silhouette : (seam ? creases : (crease ? self.faces : nil))
				if let tone {
					raster.bitmap.gray[i] = min(source.gray[i], tone)
					raster.outlined[i] = true
				}
			}
		}
	}
}
