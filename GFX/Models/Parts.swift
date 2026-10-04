/// Authoring helpers shared by the sprite models. Parts are sized nose-first along `+x`
/// and placed relative to the footprint centre.

func at(_ x: Float, _ y: Float, _ z: Float) -> V3 {
	V3(Volume.center.x + x, Volume.center.y + y, z)
}

func box(
	length: Float,
	width: Float,
	z: ClosedRange<Float>,
	x: Float = 0,
	y: Float = 0,
	tone: UInt8
) -> Solid {
	.box(from: at(x - length / 2, y - width / 2, z.lowerBound), to: at(x + length / 2, y + width / 2, z.upperBound), tone: tone)
}

func wedge(
	length: Float,
	width: Float,
	z: ClosedRange<Float>,
	x: Float = 0,
	y: Float = 0,
	rising: Direction,
	tone: UInt8
) -> Solid {
	.wedge(
		from: at(x - length / 2, y - width / 2, z.lowerBound),
		to: at(x + length / 2, y + width / 2, z.upperBound),
		rising: rising,
		tone: tone
	)
}

/// A pair of parts mirrored across the nose axis — wings, skids, outriggers, barrels.
func sides<Part>(_ y: Float, _ part: (Float) -> Part) -> [Part] {
	[part(-y), part(y)]
}

/// Sloped plates with an octagonal footprint. Insets measure the roof's retreat from the base.
func armour(
	length: Float, width: Float, z: ClosedRange<Float>, x: Float = 0, y: Float = 0,
	front: Float = 0, rear: Float = 0, side: Float = 0, corner: Float = 0, tone: UInt8
) -> Solid {
	var solid = box(length: length, width: width, z: z, x: x, y: y, tone: tone)
	let height = z.upperBound - z.lowerBound
	solid.planes += [
		Plane(normal: V3(height, 0, front), through: at(x + length / 2, y, z.lowerBound)),
		Plane(normal: V3(-height, 0, rear), through: at(x - length / 2, y, z.lowerBound)),
		Plane(normal: V3(0, height, side), through: at(x, y + width / 2, z.lowerBound)),
		Plane(normal: V3(0, -height, side), through: at(x, y - width / 2, z.lowerBound)),
	]
	for sx: Float in [-1, 1] {
		for sy: Float in [-1, 1] {
			solid.planes.append(Plane(
				normal: V3(sx * height, sy * height, (sx > 0 ? front : rear) + side),
				through: at(x + sx * (length - corner) / 2, y + sy * (width - corner) / 2, z.lowerBound)
			))
		}
	}
	return solid
}

enum PartAxis { case x, y, z }

/// Eight facets keep wheels, hatches and engine nacelles round at native resolution.
func cylinder(at center: V3, radius: Float, length: Float, axis: PartAxis, tone: UInt8) -> Solid {
	let extent: V3
	switch axis {
	case .x: extent = V3(length / 2, radius, radius)
	case .y: extent = V3(radius, length / 2, radius)
	case .z: extent = V3(radius, radius, length / 2)
	}
	var solid = Solid.box(from: center - extent, to: center + extent, tone: tone)
	for a: Float in [-1, 1] {
		for b: Float in [-1, 1] {
			let normal: V3
			switch axis {
			case .x: normal = V3(0, a, b)
			case .y: normal = V3(a, 0, b)
			case .z: normal = V3(a, b, 0)
			}
			solid.planes.append(Plane(normal: normal, offset: normal.dot(center) + radius * 1.4142136))
		}
	}
	return solid
}

/// An octagonal tube pitched in the x/z plane, with perpendicular end caps.
func barrel(from start: V3, to end: V3, caliber: Float, tone: UInt8) -> Solid {
	let axis = (end - start).normalized
	let across = V3(-axis.z, 0, axis.x)
	let radius = caliber / 2
	let margin = V3(abs(across.x) * radius, radius, abs(across.z) * radius)
	var planes = [Plane(normal: -axis, through: start), Plane(normal: axis, through: end)]
	let up = V3(0, 1, 0)
	for normal in [across, -across, up, -up] {
		planes.append(Plane(normal: normal, offset: normal.dot(start) + radius))
	}
	for a: Float in [-1, 1] {
		for b: Float in [-1, 1] {
			let normal = across * a + up * b
			planes.append(Plane(normal: normal, offset: normal.dot(start) + radius * 1.4142136))
		}
	}
	return Solid(planes: planes, from: start.min(end) - margin, to: start.max(end) + margin, tone: tone)
}

/// Extrudes a convex, counterclockwise outline in the horizontal plane.
func prism(_ points: [(Float, Float)], z: ClosedRange<Float>, tone: UInt8) -> Solid {
	let vertices = points.map { at($0.0, $0.1, z.lowerBound) }
	let from = vertices.reduce(vertices[0]) { $0.min($1) }
	let to = vertices.reduce(vertices[0]) { $0.max($1) } + V3(0, 0, z.upperBound - z.lowerBound)
	var solid = Solid.box(from: from, to: to, tone: tone)
	for i in vertices.indices {
		let edge = vertices[(i + 1) % vertices.count] - vertices[i]
		solid.planes.append(Plane(normal: V3(edge.y, -edge.x, 0), through: vertices[i]))
	}
	return solid
}

func hatch(x: Float, y: Float = 0, z: Float, radius: Float = 1.8, tone: UInt8 = Units.Tone.turret) -> Solid {
	cylinder(at: at(x, y, z + 0.375), radius: radius, length: 0.75, axis: .z, tone: tone)
}

func grille(x: Float, y: Float = 0, z: Float, length: Float, width: Float, tone: UInt8 = 90) -> [Line] {
	stride(from: x - length / 2, through: x + length / 2, by: 2.25).map {
		Line(from: at($0, y - width / 2, z), to: at($0, y + width / 2, z), tone: tone)
	}
}

/// The lower lip casts a narrow shadow onto the deck beneath a turret.
func turret(
	length: Float, width: Float, z: ClosedRange<Float>, x: Float = 0, y: Float = 0,
	front: Float = 1.2, rear: Float = 0.75, side: Float = 0.75, corner: Float = 1.5,
	tone: UInt8 = Units.Tone.turret
) -> Model {
	let l = length / 2, w = width / 2
	let rim = [
		at(x - l + corner, y - w, z.lowerBound), at(x + l - corner, y - w, z.lowerBound),
		at(x + l, y - w + corner, z.lowerBound), at(x + l, y + w - corner, z.lowerBound),
		at(x + l - corner, y + w, z.lowerBound), at(x - l + corner, y + w, z.lowerBound),
		at(x - l, y + w - corner, z.lowerBound), at(x - l, y - w + corner, z.lowerBound),
	]
	return Model([
		armour(length: length, width: width, z: z, x: x, y: y,
			front: front, rear: rear, side: side, corner: corner, tone: tone),
	], lines: rim.indices.map { Line(from: rim[$0], to: rim[($0 + 1) % rim.count], tone: 70) })
}
