/// Box-shaped ground units, authored nose-first along `+x` (screen right-and-down).
public enum Units {

	public enum Tone {
		public static let body: UInt8 = 215
		public static let turret: UInt8 = 195
		public static let barrel: UInt8 = 165
		public static let cargo: UInt8 = 205
		public static let glass: UInt8 = 145
		public static let running: UInt8 = 120
		public static let wheel: UInt8 = 95
	}

	public static var tank: Model {
		Model([
			box(length: 24, width: 13, z: 0 ... 3, tone: Tone.running),
			box(length: 21, width: 10, z: 3 ... 7, x: -1),
			wedge(length: 6, width: 10, z: 3.5 ... 7, x: 8.5, rising: .xMinus),
			box(length: 11, width: 9, z: 7 ... 11, x: -3, tone: Tone.turret),
			box(length: 15, width: 2, z: 8.5 ... 10.5, x: 8, tone: Tone.barrel),
		])
	}

	public static var truck: Model {
		Model(wheels(at: [-8, -1.5, 7]) + [
			box(length: 25, width: 8, z: 2.5 ... 4.5, tone: Tone.running),
			box(length: 14, width: 11, z: 4.5 ... 11, x: -5, tone: Tone.cargo),
			box(length: 8, width: 10, z: 4.5 ... 8, x: 8),
			box(length: 6.5, width: 9, z: 8 ... 10, x: 7, tone: Tone.glass),
		])
	}

	/// Wheeled APC / IFV: sloped bow over a low hull, in the shape of `bxr.png`.
	public static var carrier: Model {
		Model(wheels(at: [-8, 0, 8]) + [
			box(length: 22, width: 10, z: 3 ... 8, x: -1),
			wedge(length: 7, width: 10, z: 4.5 ... 8, x: 8.5, rising: .xMinus),
			box(length: 7, width: 7, z: 8 ... 11, x: -4, tone: Tone.turret),
			box(length: 9, width: 2, z: 9 ... 10.5, x: 3, tone: Tone.barrel),
		])
	}

	/// Tracked gun: long barrel over a boxy superstructure.
	public static var artillery: Model {
		Model([
			box(length: 22, width: 13, z: 0 ... 3, tone: Tone.running),
			box(length: 19, width: 10, z: 3 ... 6, x: -1),
			box(length: 13, width: 9, z: 6 ... 10.5, x: -4, tone: Tone.turret),
			box(length: 19, width: 2, z: 9 ... 11, x: 7, tone: Tone.barrel),
		])
	}

	/// Flat-bed launcher: raked cells over a truck chassis.
	public static var launcher: Model {
		Model(wheels(at: [-8, -1.5, 7]) + [
			box(length: 25, width: 8, z: 2.5 ... 4.5, tone: Tone.running),
			box(length: 8, width: 10, z: 4.5 ... 9, x: 8),
			wedge(length: 16, width: 10, z: 4.5 ... 12.5, x: -4.5, rising: .xMinus, tone: Tone.cargo),
		])
	}
}

private extension Units {

	static func box(
		length: Float,
		width: Float,
		z: ClosedRange<Float>,
		x: Float = 0,
		y: Float = 0,
		tone: UInt8 = Tone.body
	) -> Solid {
		.box(
			from: corner(length, width, z, x, y, low: true),
			to: corner(length, width, z, x, y, low: false),
			tone: tone
		)
	}

	static func wedge(
		length: Float,
		width: Float,
		z: ClosedRange<Float>,
		x: Float = 0,
		y: Float = 0,
		rising: Direction,
		tone: UInt8 = Tone.body
	) -> Solid {
		.wedge(
			from: corner(length, width, z, x, y, low: true),
			to: corner(length, width, z, x, y, low: false),
			rising: rising,
			tone: tone
		)
	}

	static func wheels(at positions: [Float]) -> [Solid] {
		positions.map { box(length: 4, width: 12, z: 0 ... 3, x: $0, tone: Tone.wheel) }
	}

	static func corner(
		_ length: Float,
		_ width: Float,
		_ z: ClosedRange<Float>,
		_ x: Float,
		_ y: Float,
		low: Bool
	) -> V3 {
		let c = Volume.center
		let sign: Float = low ? -1 : 1
		return V3(
			c.x + x + sign * length / 2,
			c.y + y + sign * width / 2,
			low ? z.lowerBound : z.upperBound
		)
	}
}
