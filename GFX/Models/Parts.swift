/// Authoring helpers shared by the sprite models. Parts are sized nose-first along `+x`
/// and placed relative to the footprint centre, so a model reads as a list of blocks.

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
