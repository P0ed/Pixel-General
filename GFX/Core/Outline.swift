/// Post-pass darkening: a rim inside the sprite's edge, seams where a part sits behind
/// another, and creases where one solid's own faces meet.
public struct Outline: Hashable, Sendable {
	public var silhouette: UInt8?
	public var creases: UInt8?
	public var faces: UInt8?
	public var depth: Float
	var tileEdgeInset: Float?

	public init(silhouette: UInt8? = nil, creases: UInt8? = nil, faces: UInt8? = nil, depth: Float = 0.75) {
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

	/// Flat tile art: a rim only a little darker than the paint it edges.
	public static var decal: Outline { Outline(silhouette: 132) }

	static func connectedDecal(inset: Float = 0) -> Outline {
		var outline = decal
		outline.tileEdgeInset = inset
		return outline
	}
}

extension Outline {

	func apply(to raster: inout Renderer.Raster, solids: [Solid], canvas: Canvas) {
		guard silhouette != nil || creases != nil || faces != nil
			|| solids.contains(where: { $0.outline != nil }) else { return }
		let source = raster.bitmap

		for y in 0 ..< source.height {
			for x in 0 ..< source.width {
				let i = source.index(x: x, y: y)
				guard source.alpha[i] > 0 else { continue }
				let id = raster.ids[i]
				let solid = solids[Int(id)]
				let outline = solid.outline ?? self

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
					let neighborID = raster.ids[n]
					let belowDecal = outline.tileEdgeInset != nil && neighborID >= 0
						&& solids[Int(neighborID)].to.z < solid.from.z
					if neighborID < 0 || belowDecal {
						rim = rim || outline.keepsRim(of: solid, atX: nx, y: ny, on: canvas)
					} else if neighborID != id {
						let neighbor = solids[Int(neighborID)]
						if outline.tileEdgeInset == nil && neighbor.outline?.tileEdgeInset != nil {
							rim = true
						} else {
							seam = seam || raster.depths[n] > raster.depths[i] + outline.depth
						}
					} else if raster.faces[n] != raster.faces[i] {
						// Only the darker side of the crease takes the line, so it stays 1 face thick.
						crease = crease || source.gray[i] < source.gray[n]
							|| (source.gray[i] == source.gray[n] && raster.faces[i] > raster.faces[n])
					}
				}

				let tone = rim ? outline.silhouette : (seam ? outline.creases : (crease ? outline.faces : nil))
				if let tone {
					raster.bitmap.gray[i] = min(source.gray[i], tone)
					raster.outlined[i] = true
				}
			}
		}
	}

	private func keepsRim(of solid: Solid, atX x: Int, y: Int, on canvas: Canvas) -> Bool {
		guard let inset = tileEdgeInset else { return true }
		let ray = canvas.origin(x: x, y: y)
		let point = V3(ray.x - ray.z, ray.y - ray.z, 0)
		let edge = 0 ... Volume.footprint
		guard edge.contains(point.x), edge.contains(point.y) else { return false }

		let far = Volume.footprint - inset
		let clamped = point.max(V3(inset, inset, 0)).min(V3(far, far, 0))
		return point == clamped || !solid.contains(clamped)
	}
}
