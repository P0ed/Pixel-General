/// Airborne units, authored nose-first along `+x` and hovering clear of the ground.
public enum Aircraft {

	public enum Tone {
		public static let body: UInt8 = 205
		public static let wing: UInt8 = 185
		public static let boom: UInt8 = 195
		public static let glass: UInt8 = 140
		public static let blade: UInt8 = 64
		public static let gear: UInt8 = 96
	}

	public static let altitude: Float = 7

	/// Utility helicopter with a faceted cabin, glazed cockpit, engine housings and skid gear.
	public static var helicopter: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 15, width: 7, z: deck ... deck + 5.5, x: 1,
				nose: 3.5, tail: 1.5, tone: Tone.body),
			fuselage(length: 7, width: 6.2, z: deck + 2 ... deck + 5.6, x: 4.5,
				nose: 3, tail: 0.6, tone: Tone.glass),
			fuselage(length: 11, width: 1.8, z: deck + 3 ... deck + 4.8, x: -10.8,
				nose: 0, tail: 2, tone: Tone.boom),
			fin(x: -14.5, z: deck + 4, chord: 3.3, height: 4.5, rake: 1.8, tone: Tone.boom),
			cylinder(at: at(-1, 0, deck + 7.2), radius: 0.8, length: 2, axis: .z, tone: Tone.gear),
		]
		solids += sides(1.7) {
			cylinder(at: at(-2.5, $0, deck + 6), radius: 1, length: 5, axis: .x, tone: Tone.boom)
		}
		solids += sides(1.7) {
			cylinder(at: at(-5.2, $0, deck + 6), radius: 0.65, length: 0.5, axis: .x, tone: Tone.gear)
		}
		solids += sides(3.45) {
			box(length: 3.5, width: 0.2, z: deck + 2 ... deck + 4.3, x: -1.5, y: $0, tone: Tone.glass)
		}
		solids += sides(3.6) {
			barrel(from: at(-5, $0, deck - 1.8), to: at(4, $0, deck - 1.8), caliber: 0.7, tone: Tone.gear)
		}
		var lines = Line.rotor(at: at(-1, 0, deck + 8.3), radius: 15, tone: Tone.blade)
		lines += tailRotor(x: -15.3, z: deck + 5.5, radius: 2.2)
		lines += [-3, 2].flatMap { x in
			sides(3.6) { Line(from: at(x, $0, deck + 0.7), to: at(x, $0, deck - 1.8), tone: Tone.gear) }
		}
		lines += sides(3.6) { Line(from: at(4, $0, deck - 1.8), to: at(5, $0, deck - 1), tone: Tone.gear) }
		lines += [
			Line(from: at(2.3, 0, deck + 5.5), to: at(6.8, 0, deck + 3), tone: Tone.boom),
			Line(from: at(-3.3, 3.6, deck + 1), to: at(-3.3, 3.45, deck + 4.4), tone: 120),
		]
		return Model(solids, lines: lines)
	}

	/// Rotary-wing UAV with a compact engine, tapered tail boom and an underslung sensor ball.
	public static var scout: Model {
		let deck = altitude + 1
		let solids = [
			fuselage(length: 11, width: 4.8, z: deck ... deck + 3.8, x: 1,
				nose: 2.5, tail: 1.5, tone: Tone.body),
			fuselage(length: 9, width: 1.4, z: deck + 2 ... deck + 3.2, x: -8.7,
				nose: 0, tail: 1.5, tone: Tone.boom),
			fin(x: -11.5, z: deck + 2.5, chord: 2.5, height: 3.5, rake: 1.3, tone: Tone.boom),
			cylinder(at: at(-1, 0, deck + 4.2), radius: 0.8, length: 3.5, axis: .x, tone: Tone.boom),
			cylinder(at: at(-1, 0, deck + 5), radius: 0.6, length: 1.5, axis: .z, tone: Tone.gear),
			cylinder(at: at(3.3, 0, deck - 0.5), radius: 1, length: 1.5, axis: .z, tone: Tone.glass),
		]
		var lines = Line.rotor(at: at(-1, 0, deck + 5.9), radius: 11, tone: Tone.blade)
		lines += tailRotor(x: -12.3, z: deck + 3.8, radius: 1.7)
		lines += sides(2.5) { y in
			[
				Line(from: at(-3, y, deck), to: at(-3, y, deck - 1.8), tone: Tone.gear),
				Line(from: at(-3, y, deck - 1.8), to: at(2, y, deck - 1.8), tone: Tone.gear),
			]
		}.flatMap { $0 }
		lines += grille(x: -1, z: deck + 3.85, length: 3, width: 2.8, tone: 130)
		return Model(solids, lines: lines)
	}

	/// Long-wing UAV with a shaped nose, sensor turret, pusher propeller and twin tail fins.
	public static var drone: Model {
		let deck = altitude + 1
		var solids = [
			fuselage(length: 12, width: 3, z: deck ... deck + 4, x: 4.5,
				nose: 3, tail: 0.3, tone: Tone.body),
			fuselage(length: 11, width: 1.5, z: deck + 1.5 ... deck + 2.7, x: -8,
				nose: 0, tail: 1.5, tone: Tone.boom),
			prism([(-15, -5), (-12, -5), (-10.5, -1.5), (-10.5, 1.5), (-12, 5), (-15, 5)],
				z: deck + 2 ... deck + 2.8, tone: Tone.wing),
			cylinder(at: at(8, 0, deck - 0.4), radius: 0.9, length: 1.6, axis: .z, tone: Tone.glass),
		]
		// Flush, equal wing spans preserve equal visible top areas in both facings.
		solids += sides(7.75) { box(length: 4, width: 12.5, z: deck + 3 ... deck + 4, x: 2, y: $0, tone: Tone.wing) }
		solids += sides(4.5) { fin(x: -13, y: $0, z: deck + 2.5, chord: 3, height: 3, rake: 1, tone: Tone.wing) }
		let lines = [
			Line(from: at(10.3, 0, deck + 2), to: at(14, 0, deck + 2), tone: Tone.blade),
			Line(from: at(-2, -3, deck + 2.5), to: at(-2, 3, deck + 2.5), tone: Tone.blade),
		] + sides(1) { sign in
			Line(from: at(0.6, sign * 2, deck + 4), to: at(0.6, sign * 13.5, deck + 4), tone: 140)
		}
		return Model(solids, lines: lines)
	}

	/// Single-engine fighter: pointed radome, bubble canopy, chin intake and swept tailplanes.
	public static var jet: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 27, width: 4.4, z: deck + 1 ... deck + 4.3, x: 0.5,
				nose: 5, tail: 0.5, tone: Tone.body),
			fuselage(length: 6, width: 3, z: deck + 4 ... deck + 6, x: 4.3,
				nose: 2.5, tail: 1, tone: Tone.glass),
			armour(length: 4.5, width: 4.5, z: deck + 0.7 ... deck + 2.5, x: 1,
				front: 0.8, side: 0.5, corner: 0.8, tone: Tone.gear),
			fin(x: -10, z: deck + 3.5, chord: 4.5, height: 5, rake: 2.3, tone: Tone.wing),
			cylinder(at: at(-12.2, 0, deck + 2.7), radius: 1.25, length: 2.6, axis: .x, tone: Tone.gear),
			cylinder(at: at(-13.6, 0, deck + 2.7), radius: 0.8, length: 0.3, axis: .x, tone: Tone.blade),
		]
		solids += swept(span: 14, root: 11, tip: 3, sweep: 5, x: 0, z: deck + 1.8, tone: Tone.wing)
		solids += swept(span: 5, root: 5, tip: 2, sweep: 2, x: -10, z: deck + 1.5, tone: Tone.wing)
		solids += stores(y: 10, x: -4, z: deck + 1.1)
		return Model(solids, lines: wingSeams(span: 14, root: 11, sweep: 5, tip: 3, x: 0, z: deck + 2.75) + [
			Line(from: at(13.6, 0, deck + 2.65), to: at(16.5, 0, deck + 2.65), tone: Tone.blade),
			Line(from: at(2.5, 0, deck + 6), to: at(5.5, 0, deck + 5.1), tone: Tone.boom),
		])
	}

	/// Twin-engine fighter with separate nacelles, side intakes, swept stabilizers and two raked fins.
	public static var heavyJet: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 29, width: 6, z: deck + 1 ... deck + 4.5, x: 0.5,
				nose: 6, tail: 0.5, tone: Tone.body),
			fuselage(length: 6.5, width: 3.5, z: deck + 4.2 ... deck + 6.3, x: 5,
				nose: 2.5, tail: 1.2, tone: Tone.glass),
		]
		solids += sides(2.1) { cylinder(at: at(-6, $0, deck + 2.8), radius: 1.5, length: 13, axis: .x, tone: Tone.boom) }
		solids += sides(2.1) { cylinder(at: at(-12.8, $0, deck + 2.8), radius: 1.1, length: 0.7, axis: .x, tone: Tone.gear) }
		solids += sides(2.6) {
			armour(length: 4.5, width: 2, z: deck + 0.8 ... deck + 3.2, x: 0, y: $0,
				front: 0.8, corner: 0.4, tone: Tone.gear)
		}
		solids += swept(span: 16, root: 14, tip: 3.5, sweep: 6, x: -0.5, z: deck + 1.8, tone: Tone.wing)
		solids += swept(span: 6, root: 6, tip: 2, sweep: 2.5, x: -10.5, z: deck + 1.5, tone: Tone.wing)
		solids += sides(2.2) { fin(x: -10, y: $0, z: deck + 4, chord: 4.5, height: 4.6, rake: 2.5, tone: Tone.wing) }
		solids += stores(y: 12, x: -4.5, z: deck + 1.1)
		return Model(solids, lines: wingSeams(span: 16, root: 14, sweep: 6, tip: 3.5, x: -0.5, z: deck + 2.75) + [
			Line(from: at(14.5, 0, deck + 2.75), to: at(17.5, 0, deck + 2.75), tone: Tone.blade),
			Line(from: at(3, 0, deck + 6.3), to: at(6.3, 0, deck + 5.2), tone: Tone.boom),
		])
	}
}

private extension Aircraft {

	/// Faceted cross-section with a nose and tail that taper in both plan and elevation.
	static func fuselage(
		length: Float, width: Float, z: ClosedRange<Float>, x: Float,
		nose: Float, tail: Float, tone: UInt8
	) -> Solid {
		var solid = box(length: length, width: width, z: z, x: x, tone: tone)
		let halfHeight = (z.upperBound - z.lowerBound) / 2
		let centerZ = (z.upperBound + z.lowerBound) / 2
		for sign: Float in [-1, 1] {
			solid.planes += [
				Plane(normal: V3(width / 2, sign * nose, 0), through: at(x + length / 2, 0, centerZ)),
				Plane(normal: V3(-width / 2, sign * tail, 0), through: at(x - length / 2, 0, centerZ)),
				Plane(normal: V3(halfHeight, 0, sign * nose), through: at(x + length / 2, 0, centerZ)),
				Plane(normal: V3(-halfHeight, 0, sign * tail), through: at(x - length / 2, 0, centerZ)),
			]
			for vertical: Float in [-1, 1] {
				let normal = V3(0, sign, vertical)
				solid.planes.append(Plane(normal: normal,
					offset: normal.dot(at(x, 0, centerZ)) + width / 2 + halfHeight - min(0.6, width / 4)))
			}
		}
		return solid
	}

	static func fin(
		x: Float, y: Float = 0, z: Float, chord: Float, height: Float, rake: Float, tone: UInt8
	) -> Solid {
		let rear = min(x - chord / 2, x - rake)
		let front = x + chord / 2
		var solid = box(length: front - rear, width: 0.9, z: z ... z + height,
			x: (front + rear) / 2, y: y, tone: tone)
		solid.planes += [
			Plane(normal: V3(height, 0, rake), through: at(front, y, z)),
			Plane(normal: V3(-height, 0, chord / 2 - rake), through: at(x - chord / 2, y, z)),
		]
		return solid
	}

	static func swept(span: Float, root: Float, tip: Float, sweep: Float, x: Float, z: Float, tone: UInt8) -> [Solid] {
		let rear = min(x - root / 2, x - sweep - tip / 2)
		let front = x + root / 2
		return sides(1) { sign in
			var wing = box(length: front - rear, width: span, z: z ... z + 0.9,
				x: (front + rear) / 2, y: sign * span / 2, tone: tone)
			wing.planes += [
				Plane(normal: V3(1, sign * (root / 2 + sweep - tip / 2) / span, 0), through: at(front, 0, z)),
				Plane(normal: V3(-1, sign * (root / 2 - sweep - tip / 2) / span, 0), through: at(x - root / 2, 0, z)),
			]
			return wing
		}
	}

	static func wingSeams(span: Float, root: Float, sweep: Float, tip: Float, x: Float, z: Float) -> [Line] {
		sides(1) { sign in
			let slope = (root / 2 + sweep - tip / 2) / span
			return Line(from: at(x + root / 2 - slope * 3 - 0.8, sign * 3, z),
				to: at(x - sweep + tip / 2 - 0.8, sign * span, z), tone: 145)
		}
	}

	static func stores(y: Float, x: Float, z: Float) -> [Solid] {
		sides(y) {
			cylinder(at: at(x, $0, z), radius: 0.55, length: 5, axis: .x, tone: Tone.boom)
		} + sides(y) {
			box(length: 1.5, width: 0.6, z: z + 0.5 ... z + 1.4, x: x, y: $0, tone: Tone.gear)
		}
	}

	static func tailRotor(x: Float, z: Float, radius: Float) -> [Line] {
		[
			Line(from: at(x, -radius, z), to: at(x, radius, z), tone: Tone.blade),
			Line(from: at(x, 0, z - radius), to: at(x, 0, z + radius), tone: Tone.blade),
		]
	}
}
