/// Airborne units, authored nose-first along `+x` and hovering clear of the ground.
/// Rotor discs, aerials and pitot booms are strokes; everything else is blocks.
public enum Aircraft {

	public enum Tone {
		public static let body: UInt8 = 205
		public static let wing: UInt8 = 185
		public static let boom: UInt8 = 195
		public static let glass: UInt8 = 140
		public static let blade: UInt8 = 64
		public static let gear: UInt8 = 96
	}

	/// Height the fuselage floats at, so an aircraft reads as flying over its tile.
	public static let altitude: Float = 7

	public static var helicopter: Model {
		let deck = altitude
		var solids = [
			box(length: 10, width: 7, z: deck ... deck + 5.5, x: -1, tone: Tone.body),
			wedge(length: 5, width: 7, z: deck + 1 ... deck + 5.5, x: 6.5, rising: .xMinus, tone: Tone.body),
			box(length: 4, width: 6, z: deck + 2.5 ... deck + 5, x: 4.5, tone: Tone.glass),
			box(length: 11, width: 2, z: deck + 3 ... deck + 4.5, x: -11, tone: Tone.boom),
			box(length: 2, width: 1.5, z: deck + 4 ... deck + 7.5, x: -15.5, tone: Tone.boom),
			box(length: 3, width: 3, z: deck + 5.5 ... deck + 6.5, x: -1, tone: Tone.boom),
		]
		solids += sides(3.5) { box(length: 9, width: 1, z: deck - 2 ... deck - 1.5, x: -1, y: $0, tone: Tone.gear) }

		var lines = Line.rotor(at: at(-1, 0, deck + 7), radius: 15, tone: Tone.blade)
		lines.append(Line(from: at(-15.5, 0, deck + 4.5), to: at(-15.5, 0, deck + 8.5), tone: Tone.blade))
		lines += [-4, 2].flatMap { x in
			sides(3.5) { Line(from: at(x, $0, deck), to: at(x, $0, deck - 2), tone: Tone.gear) }
		}

		return Model(solids, lines: lines)
	}

	/// Rotary-wing UAV: the same layout, two thirds the size, no cabin glass.
	public static var scout: Model {
		let deck = altitude + 1
		let solids = [
			box(length: 8, width: 5, z: deck ... deck + 4, x: -1, tone: Tone.body),
			wedge(length: 3.5, width: 5, z: deck + 0.5 ... deck + 4, x: 4.5, rising: .xMinus, tone: Tone.body),
			box(length: 9, width: 1.5, z: deck + 2 ... deck + 3, x: -9, tone: Tone.boom),
			box(length: 1.5, width: 1, z: deck + 2.5 ... deck + 5.5, x: -12.5, tone: Tone.boom),
			box(length: 2.5, width: 2.5, z: deck + 4 ... deck + 5, x: -1, tone: Tone.boom),
		]

		var lines = Line.rotor(at: at(-1, 0, deck + 5.5), radius: 11, tone: Tone.blade)
		lines.append(Line(from: at(-12.5, 0, deck + 3), to: at(-12.5, 0, deck + 7), tone: Tone.blade))
		lines += sides(2.5) { Line(from: at(-1, $0, deck), to: at(-1, $0, deck - 2), tone: Tone.gear) }

		return Model(solids, lines: lines)
	}

	/// Fixed-wing UAV: straight high wing, slim boom, twin tail.
	public static var drone: Model {
		let deck = altitude + 1
		var solids = [
			box(length: 9, width: 3, z: deck ... deck + 3, x: 3, tone: Tone.body),
			wedge(length: 3, width: 3, z: deck + 0.5 ... deck + 3, x: 9, rising: .xMinus, tone: Tone.body),
			box(length: 11, width: 1.5, z: deck + 1.5 ... deck + 2.5, x: -8, tone: Tone.boom),
			box(length: 3, width: 15, z: deck + 3 ... deck + 3.7, x: 2, tone: Tone.wing),
			box(length: 2, width: 7, z: deck + 2 ... deck + 2.6, x: -13, tone: Tone.wing),
		]
		solids += sides(3.5) { box(length: 2, width: 1.2, z: deck + 2.5 ... deck + 5, x: -13, y: $0, tone: Tone.wing) }

		let lines = [Line(from: at(11, 0, deck + 1.5), to: at(15, 0, deck + 1.5), tone: Tone.blade)]
		return Model(solids, lines: lines)
	}

	/// Single-seat jet: swept wing stepped back in three panels, slab tail.
	public static var jet: Model {
		let deck = altitude
		var solids = [
			box(length: 19, width: 4, z: deck + 1 ... deck + 4, x: -1, tone: Tone.body),
			wedge(length: 5, width: 4, z: deck + 1.5 ... deck + 4, x: 10.5, rising: .xMinus, tone: Tone.body),
			box(length: 5, width: 3.5, z: deck + 4 ... deck + 5.3, x: 4, tone: Tone.glass),
			box(length: 3, width: 9, z: deck + 1.5 ... deck + 2.2, x: -10, tone: Tone.wing),
			box(length: 4, width: 2, z: deck + 4 ... deck + 8, x: -9, tone: Tone.wing),
		]
		solids += swept(span: 9, root: 2.5, x: -1, z: deck + 1.8, tone: Tone.wing)

		let lines = [
			Line(from: at(12.5, 0, deck + 2.7), to: at(16, 0, deck + 2.7), tone: Tone.blade),
			Line(from: at(-11, 0, deck + 2.5), to: at(-15, 0, deck + 2.5), tone: Tone.blade),
		]
		return Model(solids, lines: lines)
	}

	/// Twin-tailed heavy fighter: longer, wider, two fins.
	public static var heavyJet: Model {
		let deck = altitude
		var solids = [
			box(length: 21, width: 6, z: deck + 1 ... deck + 4.5, x: -1, tone: Tone.body),
			wedge(length: 6, width: 5, z: deck + 1.5 ... deck + 4.5, x: 11, rising: .xMinus, tone: Tone.body),
			box(length: 5, width: 4, z: deck + 4.5 ... deck + 6, x: 5, tone: Tone.glass),
			box(length: 4, width: 12, z: deck + 1.5 ... deck + 2.2, x: -10.5, tone: Tone.wing),
		]
		solids += swept(span: 11, root: 3, x: -1.5, z: deck + 1.8, tone: Tone.wing)
		solids += sides(2.6) { box(length: 4.5, width: 1.6, z: deck + 4.5 ... deck + 8.5, x: -9, y: $0, tone: Tone.wing) }

		let lines = [
			Line(from: at(14.5, 0, deck + 3), to: at(18, 0, deck + 3), tone: Tone.blade),
			Line(from: at(-12.5, 0, deck + 2.8), to: at(-16, 0, deck + 2.8), tone: Tone.blade),
		]
		return Model(solids, lines: lines)
	}
}

private extension Aircraft {

	/// Three panels per side, each shorter and further aft: a delta read without a taper plane.
	static func swept(span: Float, root: Float, x: Float, z: Float, tone: UInt8) -> [Solid] {
		(0 ..< 3).flatMap { panel -> [Solid] in
			let step = span / 3
			let inset = Float(panel)
			return sides(step * (inset + 0.5)) {
				box(
					length: root - inset * root / 4,
					width: step,
					z: z ... z + 0.7,
					x: x - inset * root / 3,
					y: $0,
					tone: tone
				)
			}
		}
	}
}
