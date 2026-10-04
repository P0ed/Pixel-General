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

	public static let altitude: Float = 10.5

	/// NH90 with a faceted cabin, glazed cockpit, twin engines and wheeled landing gear.
	public static var nh90: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 22.5, width: 10.5, z: deck ... deck + 8.25, x: 1.5,
				nose: 5.25, tail: 2.25, tone: Tone.body),
			fuselage(length: 10.5, width: 9.3, z: deck + 3 ... deck + 8.4, x: 6.75,
				nose: 4.5, tail: 0.9, tone: Tone.glass),
			fuselage(length: 16.5, width: 2.7, z: deck + 4.5 ... deck + 7.2, x: -16.2,
				nose: 0, tail: 3, tone: Tone.boom),
			fin(x: -21.75, z: deck + 6, chord: 4.95, height: 6.75, rake: 2.7, tone: Tone.boom),
			cylinder(at: at(-1.5, 0, deck + 10.8), radius: 1.2, length: 3, axis: .z, tone: Tone.gear),
		]
		solids += sides(2.55) {
			cylinder(at: at(-3.75, $0, deck + 9), radius: 1.5, length: 7.5, axis: .x, tone: Tone.boom)
		}
		solids += sides(2.55) {
			cylinder(at: at(-7.8, $0, deck + 9), radius: 0.975, length: 0.75, axis: .x, tone: Tone.gear)
		}
		solids += sides(5.175) {
			box(length: 5.25, width: 0.3, z: deck + 3 ... deck + 6.45, x: -2.25, y: $0, tone: Tone.glass)
		}
		solids += sides(6) {
			cylinder(at: at(-5.25, $0, deck - 1.65), radius: 1.2, length: 1.2, axis: .y, tone: Tone.gear)
		}
		solids.append(cylinder(at: at(7.5, 0, deck - 1.65), radius: 1.05, length: 1.2, axis: .y, tone: Tone.gear))
		var lines = Line.rotor(at: at(-1.5, 0, deck + 12.45), radius: 22.5, tone: Tone.blade)
		lines += tailRotor(x: -22.95, z: deck + 8.25, radius: 3.3)
		lines += sides(6) { Line(from: at(-5.25, $0, deck - 1.65), to: at(-5.25, $0, deck + 1.5), tone: Tone.gear) }
		lines.append(Line(from: at(7.5, 0, deck - 1.65), to: at(7.5, 0, deck + 1.5), tone: Tone.gear))
		lines += [
			Line(from: at(3.45, 0, deck + 8.25), to: at(10.2, 0, deck + 4.5), tone: Tone.boom),
			Line(from: at(-4.95, 5.4, deck + 1.5), to: at(-4.95, 5.175, deck + 6.6), tone: 120),
		]
		return Model(solids, lines: lines)
	}

	/// Rotary-wing UAV with a compact engine, tapered tail boom and an underslung sensor ball.
	public static var skeldar: Model {
		let deck = altitude + 1.5
		let solids = [
			fuselage(length: 16.5, width: 7.2, z: deck ... deck + 5.7, x: 1.5,
				nose: 3.75, tail: 2.25, tone: Tone.body),
			fuselage(length: 13.5, width: 2.1, z: deck + 3 ... deck + 4.8, x: -13.05,
				nose: 0, tail: 2.25, tone: Tone.boom),
			fin(x: -17.25, z: deck + 3.75, chord: 3.75, height: 5.25, rake: 1.95, tone: Tone.boom),
			cylinder(at: at(-1.5, 0, deck + 6.3), radius: 1.2, length: 5.25, axis: .x, tone: Tone.boom),
			cylinder(at: at(-1.5, 0, deck + 7.5), radius: 0.9, length: 2.25, axis: .z, tone: Tone.gear),
			cylinder(at: at(4.95, 0, deck - 0.75), radius: 1.5, length: 2.25, axis: .z, tone: Tone.glass),
		]
		var lines = Line.rotor(at: at(-1.5, 0, deck + 8.85), radius: 16.5, tone: Tone.blade)
		lines += tailRotor(x: -18.45, z: deck + 5.7, radius: 2.55)
		lines += sides(3.75) { y in
			[
				Line(from: at(-4.5, y, deck), to: at(-4.5, y, deck - 2.7), tone: Tone.gear),
				Line(from: at(-4.5, y, deck - 2.7), to: at(3, y, deck - 2.7), tone: Tone.gear),
			]
		}.flatMap { $0 }
		lines += grille(x: -1.5, z: deck + 5.775, length: 4.5, width: 4.2, tone: 130)
		return Model(solids, lines: lines)
	}

	/// Long-wing UAV with a shaped nose, sensor turret, pusher propeller and twin tail fins.
	public static var mq9: Model {
		let deck = altitude + 1.5
		var solids = [
			fuselage(length: 18, width: 4.5, z: deck ... deck + 6, x: 6.75,
				nose: 4.5, tail: 0.45, tone: Tone.body),
			fuselage(length: 22.5, width: 2.25, z: deck + 2.25 ... deck + 4.05, x: -9,
				nose: 0, tail: 2.25, tone: Tone.boom),
			prism([(-22.5, -7.5), (-18, -7.5), (-15.75, -2.25), (-15.75, 2.25), (-18, 7.5), (-22.5, 7.5)],
				z: deck + 3 ... deck + 4.2, tone: Tone.wing),
			cylinder(at: at(12, 0, deck - 0.6), radius: 1.35, length: 2.4, axis: .z, tone: Tone.glass),
		]
		// Flush, equal wing spans preserve equal visible top areas in both facings.
		solids += sides(11.625) { box(length: 6, width: 18.75, z: deck + 4.5 ... deck + 6, x: 3, y: $0, tone: Tone.wing) }
		solids += sides(6.75) { fin(x: -19.5, y: $0, z: deck + 3.75, chord: 4.5, height: 4.5, rake: 1.5, tone: Tone.wing) }
		let lines = [
			Line(from: at(15.45, 0, deck + 3), to: at(21, 0, deck + 3), tone: Tone.blade),
			Line(from: at(-3, -4.5, deck + 3.75), to: at(-3, 4.5, deck + 3.75), tone: Tone.blade),
		] + sides(1) { sign in
			Line(from: at(0.9, sign * 3, deck + 6), to: at(0.9, sign * 20.25, deck + 6), tone: 140)
		}
		return Model(solids, lines: lines)
	}

	/// Single-engine fighter: pointed radome, bubble canopy, chin intake and swept tailplanes.
	public static var f16: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 40.5, width: 6.6, z: deck + 1.5 ... deck + 6.45, x: 0.75,
				nose: 7.5, tail: 0.75, tone: Tone.body),
			fuselage(length: 9, width: 4.5, z: deck + 6 ... deck + 9, x: 6.45,
				nose: 3.75, tail: 1.5, tone: Tone.glass),
			armour(length: 6.75, width: 6.75, z: deck + 1.05 ... deck + 3.75, x: 1.5,
				front: 1.2, side: 0.75, corner: 1.2, tone: Tone.gear),
			fin(x: -15, z: deck + 5.25, chord: 6.75, height: 7.5, rake: 3.45, tone: Tone.wing),
			cylinder(at: at(-18.3, 0, deck + 4.05), radius: 1.875, length: 3.9, axis: .x, tone: Tone.gear),
			cylinder(at: at(-20.4, 0, deck + 4.05), radius: 1.2, length: 0.45, axis: .x, tone: Tone.blade),
		]
		solids += swept(span: 21, root: 16.5, tip: 4.5, sweep: 7.5, x: 0, z: deck + 2.7, tone: Tone.wing)
		solids += swept(span: 7.5, root: 7.5, tip: 3, sweep: 3, x: -15, z: deck + 2.25, tone: Tone.wing)
		solids += stores(y: 15, x: -6, z: deck + 1.65)
		return Model(solids, lines: wingSeams(span: 21, root: 16.5, sweep: 7.5, tip: 4.5, x: 0, z: deck + 4.125) + [
			Line(from: at(20.4, 0, deck + 3.975), to: at(24.75, 0, deck + 3.975), tone: Tone.blade),
			Line(from: at(3.75, 0, deck + 9), to: at(8.25, 0, deck + 7.65), tone: Tone.boom),
		])
	}

	/// Twin-engine fighter with separate nacelles, side intakes, swept stabilizers and two raked fins.
	public static var mig29: Model {
		let deck = altitude
		var solids = [
			fuselage(length: 43.5, width: 9, z: deck + 1.5 ... deck + 6.75, x: 0.75,
				nose: 9, tail: 0.75, tone: Tone.body),
			fuselage(length: 9.75, width: 5.25, z: deck + 6.3 ... deck + 9.45, x: 7.5,
				nose: 3.75, tail: 1.8, tone: Tone.glass),
		]
		solids += sides(3.15) { cylinder(at: at(-9, $0, deck + 4.2), radius: 2.25, length: 19.5, axis: .x, tone: Tone.boom) }
		solids += sides(3.15) { cylinder(at: at(-19.2, $0, deck + 4.2), radius: 1.65, length: 1.05, axis: .x, tone: Tone.gear) }
		solids += sides(3.9) {
			armour(length: 6.75, width: 3, z: deck + 1.2 ... deck + 4.8, x: 0, y: $0,
				front: 1.2, corner: 0.6, tone: Tone.gear)
		}
		solids += swept(span: 24, root: 21, tip: 5.25, sweep: 9, x: -0.75, z: deck + 2.7, tone: Tone.wing)
		solids += swept(span: 9, root: 9, tip: 3, sweep: 3.75, x: -15.75, z: deck + 2.25, tone: Tone.wing)
		solids += sides(3.3) { fin(x: -15, y: $0, z: deck + 6, chord: 6.75, height: 6.9, rake: 3.75, tone: Tone.wing) }
		solids += stores(y: 18, x: -6.75, z: deck + 1.65)
		return Model(solids, lines: wingSeams(span: 24, root: 21, sweep: 9, tip: 5.25, x: -0.75, z: deck + 4.125) + [
			Line(from: at(21.75, 0, deck + 4.125), to: at(26.25, 0, deck + 4.125), tone: Tone.blade),
			Line(from: at(4.5, 0, deck + 9.45), to: at(9.45, 0, deck + 7.8), tone: Tone.boom),
		])
	}
}

extension Aircraft {

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
					offset: normal.dot(at(x, 0, centerZ)) + width / 2 + halfHeight - min(0.9, width / 4)))
			}
		}
		return solid
	}

	static func fin(
		x: Float, y: Float = 0, z: Float, chord: Float, height: Float, rake: Float, tone: UInt8
	) -> Solid {
		let rear = min(x - chord / 2, x - rake)
		let front = x + chord / 2
		var solid = box(length: front - rear, width: 1.35, z: z ... z + height,
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
			var wing = box(length: front - rear, width: span, z: z ... z + 1.35,
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
			return Line(from: at(x + root / 2 - slope * 4.5 - 1.2, sign * 4.5, z),
				to: at(x - sweep + tip / 2 - 1.2, sign * span, z), tone: 145)
		}
	}

	static func stores(y: Float, x: Float, z: Float) -> [Solid] {
		sides(y) {
			cylinder(at: at(x, $0, z), radius: 0.825, length: 7.5, axis: .x, tone: Tone.boom)
		} + sides(y) {
			box(length: 2.25, width: 0.9, z: z + 0.75 ... z + 2.1, x: x, y: $0, tone: Tone.gear)
		}
	}

	static func tailRotor(x: Float, z: Float, radius: Float) -> [Line] {
		[
			Line(from: at(x, -radius, z), to: at(x, radius, z), tone: Tone.blade),
			Line(from: at(x, 0, z - radius), to: at(x, 0, z + radius), tone: Tone.blade),
		]
	}
}
