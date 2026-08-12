/// Naval units, authored bow-first along `+x` and floating on the tile surface.
/// Masts and rigging are strokes; hull, superstructure and turrets are blocks.
public enum Ships {

	public enum Tone {
		public static let hull: UInt8 = 150
		public static let deck: UInt8 = 195
		public static let house: UInt8 = 225
		public static let turret: UInt8 = 180
		public static let barrel: UInt8 = 150
		public static let mast: UInt8 = 72
		public static let cargo: UInt8 = 205
	}

	public static var cargo: Model {
		var solids = [
			box(length: 26, width: 9, z: 0 ... 3.5, x: -2, tone: Tone.hull),
			wedge(length: 6, width: 9, z: 0 ... 3.5, x: 14, rising: .xPlus, tone: Tone.hull),
			box(length: 30, width: 8, z: 3.5 ... 4.2, x: -1, tone: Tone.deck),
			box(length: 6, width: 8, z: 4.2 ... 8.5, x: -11, tone: Tone.house),
			box(length: 3, width: 3, z: 8.5 ... 11, x: -11, tone: Tone.mast),
		]
		solids += [-3, 3, 9].map { box(length: 5, width: 7, z: 4.2 ... 7, x: $0, tone: Tone.cargo) }

		let lines = [
			Line(from: at(-11, 0, 11), to: at(-11, 0, 15), tone: Tone.mast),
			Line(from: at(-11, 0, 14), to: at(-4, 0, 11.5), tone: Tone.mast),
			Line(from: at(-11, 0, 14), to: at(-16, 0, 11), tone: Tone.mast),
		]
		return Model(solids, lines: lines)
	}

	public static var destroyer: Model {
		var solids = [
			box(length: 24, width: 8, z: 0 ... 3, x: -3, tone: Tone.hull),
			wedge(length: 7, width: 8, z: 0 ... 3.5, x: 12.5, rising: .xPlus, tone: Tone.hull),
			box(length: 29, width: 7, z: 3 ... 3.7, x: -1.5, tone: Tone.deck),
			box(length: 9, width: 7, z: 3.7 ... 8, x: -3, tone: Tone.house),
			box(length: 5, width: 5, z: 8 ... 10.5, x: -4, tone: Tone.house),
			box(length: 4, width: 5, z: 3.7 ... 6.5, x: -11.5, tone: Tone.house),
		]
		solids += turret(x: 8, z: 3.7, size: 4.5, barrel: 7)

		let lines = [
			Line(from: at(-4, 0, 10.5), to: at(-4, 0, 15), tone: Tone.mast),
			Line(from: at(-4, 0, 13.5), to: at(-8.5, 0, 11), tone: Tone.mast),
			Line(from: at(-4, 0, 13.5), to: at(0.5, 0, 11), tone: Tone.mast),
			Line(from: at(-15.5, 0, 5), to: at(-15.5, 0, 9), tone: Tone.mast),
		]
		return Model(solids, lines: lines)
	}

	/// Bigger hull, two turrets and a funnel between the masts.
	public static var cruiser: Model {
		var solids = [
			box(length: 26, width: 9, z: 0 ... 3.5, x: -2, tone: Tone.hull),
			wedge(length: 7, width: 9, z: 0 ... 4, x: 14, rising: .xPlus, tone: Tone.hull),
			box(length: 31, width: 8, z: 3.5 ... 4.2, x: -1, tone: Tone.deck),
			box(length: 10, width: 8, z: 4.2 ... 9, x: -3, tone: Tone.house),
			box(length: 5, width: 5.5, z: 9 ... 12, x: -4.5, tone: Tone.house),
			box(length: 4, width: 5, z: 4.2 ... 8.5, x: -10.5, tone: Tone.mast),
		]
		solids += turret(x: 9, z: 4.2, size: 5, barrel: 8)
		solids += turret(x: -14, z: 4.2, size: 4.5, barrel: -7)

		let lines = [
			Line(from: at(-4.5, 0, 12), to: at(-4.5, 0, 16), tone: Tone.mast),
			Line(from: at(-4.5, 0, 15), to: at(-9.5, 0, 12), tone: Tone.mast),
			Line(from: at(-4.5, 0, 15), to: at(0.5, 0, 12), tone: Tone.mast),
		]
		return Model(solids, lines: lines)
	}
}

private extension Ships {

	/// Gun house plus the barrel it points, aft when `barrel` is negative.
	static func turret(x: Float, z: Float, size: Float, barrel: Float) -> [Solid] {
		[
			box(length: size, width: size, z: z ... z + 2.5, x: x, tone: Tone.turret),
			box(
				length: abs(barrel),
				width: 1.5,
				z: z + 1.2 ... z + 2.2,
				x: x + barrel / 2,
				tone: Tone.barrel
			),
		]
	}
}
