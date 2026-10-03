public extension Aircraft {

	/// Little Bird: compact glazed bubble cabin, exposed skids and a small rotor disc.
	static var mh6: Model {
		rotorcraft(length: 10, width: 5.8, height: 5.3, rotor: 11, tail: 10, skids: true)
		+ Model([
			box(length: 5, width: 1.5, z: altitude - 0.5 ... altitude + 0.2, x: -1, y: -4.1, tone: Tone.gear),
			box(length: 5, width: 1.5, z: altitude - 0.5 ... altitude + 0.2, x: -1, y: 4.1, tone: Tone.gear),
		])
	}

	/// Mi-8: long transport cabin, multiple side windows and wheeled landing gear.
	static var mi8: Model {
		rotorcraft(length: 19, width: 8, height: 6.5, rotor: 16, tail: 10, skids: false)
		+ Model(lines: [-5, -2, 1].flatMap { x in
			sides(4.05) { Line(from: at(x, $0, altitude + 3), to: at(x + 1, $0, altitude + 4), tone: Tone.glass, width: 2) }
		})
	}

	/// Mi-24: stepped tandem canopy, stub wings, rocket pods and a chin gun.
	static var mi24: Model {
		rotorcraft(length: 18, width: 6.8, height: 6, rotor: 15, tail: 10, skids: false)
		+ Model([
			fuselage(length: 5, width: 3.8, z: altitude + 3 ... altitude + 6.5, x: 3,
				nose: 1.5, tail: 1, tone: Tone.glass),
			fuselage(length: 4.5, width: 3.5, z: altitude + 1.5 ... altitude + 4.3, x: 7,
				nose: 1.8, tail: 0.5, tone: Tone.glass),
			cylinder(at: at(7.5, 0, altitude), radius: 1, length: 1.5, axis: .z, tone: Tone.gear),
			barrel(from: at(7.5, 0, altitude), to: at(12, 0, altitude), caliber: 0.7, tone: Tone.gear),
		] + swept(span: 7.5, root: 5, tip: 2, sweep: 1.5, x: -1.5, z: altitude + 2, tone: Tone.wing)
		+ sides(6.5) { cylinder(at: at(-2, $0, altitude + 1), radius: 1.2, length: 5, axis: .x, tone: Tone.gear) })
	}

	static var skeldarm: Model {
		skeldar + Model(swept(span: 4, root: 3, tip: 1.5, sweep: 0.5, x: 0, z: altitude + 1, tone: Tone.wing)
		+ stores(y: 3.5, x: 0, z: altitude))
	}

	static var mq8: Model {
		rotorcraft(length: 12.5, width: 5.5, height: 4.5, rotor: 12.5, tail: 9, skids: true, glazed: false)
		+ Model([
			cylinder(at: at(4, 0, altitude - 0.5), radius: 1.3, length: 1.5, axis: .z, tone: Tone.glass),
		] + swept(span: 4, root: 3, tip: 1, sweep: 1, x: -12, z: altitude + 3.5, tone: Tone.wing))
	}

	/// Spherical cabin and two coaxial rotors; no tail rotor or boom.
	static var ka137: Model {
		Model([
			fuselage(length: 7, width: 6, z: altitude + 1 ... altitude + 6, x: 0,
				nose: 2, tail: 2, tone: Tone.body),
			cylinder(at: at(2, 0, altitude + 0.5), radius: 1.1, length: 1.5, axis: .z, tone: Tone.glass),
			cylinder(at: at(0, 0, altitude + 7), radius: 0.6, length: 4, axis: .z, tone: Tone.gear),
		], lines: Line.rotor(at: at(0, 0, altitude + 6.5), radius: 10, tone: Tone.blade)
			+ Line.rotor(at: at(0, 0, altitude + 9), radius: 9, tone: Tone.blade)
			+ sides(3) { Line(from: at(-2, $0, altitude - 1), to: at(2, $0, altitude - 1), tone: Tone.gear) }
			+ sides(3) { Line(from: at(0, $0, altitude + 1), to: at(0, $0, altitude - 1), tone: Tone.gear) })
	}

	static var orlan: Model {
		let deck = altitude + 1
		return Model([
			fuselage(length: 16, width: 2.5, z: deck ... deck + 3, x: 0,
				nose: 2.5, tail: 6, tone: Tone.body),
			fin(x: -6, z: deck + 2, chord: 2.5, height: 3.5, rake: 1, tone: Tone.wing),
		] + swept(span: 11, root: 3.5, tip: 2.3, sweep: 0.8, x: 1.5, z: deck + 2.4, tone: Tone.wing)
		+ swept(span: 4, root: 2.5, tip: 1.4, sweep: 0.8, x: -6.3, z: deck + 1.8, tone: Tone.wing),
		lines: [Line(from: at(8.3, -2.5, deck + 1.5), to: at(8.3, 2.5, deck + 1.5), tone: Tone.blade)])
	}

	static var bayraktar: Model {
		let deck = altitude + 1
		return Model([
			fuselage(length: 21, width: 3.3, z: deck ... deck + 3.5, x: 0,
				nose: 4, tail: 6, tone: Tone.body),
			cylinder(at: at(5, 0, deck - 0.5), radius: 1, length: 1.5, axis: .z, tone: Tone.glass),
		] + swept(span: 14, root: 3.3, tip: 1.8, sweep: 0.4, x: 0, z: deck + 2.6, tone: Tone.wing)
		+ swept(span: 4.5, root: 3.3, tip: 1.5, sweep: 1.5, x: -8.5, z: deck + 1.5, tone: Tone.wing)
		+ sides(2.8) { fin(x: -8.7, y: $0, z: deck + 1.5, chord: 2.5, height: 2.4, rake: 1.4, tone: Tone.wing) }
		+ stores(y: 7, x: -0.5, z: deck + 1.8), lines: [
			Line(from: at(-5, -3, deck + 2), to: at(-5, 3, deck + 2), tone: Tone.blade),
		])
	}

	/// Gripen's silhouette is a delta wing with separate forward canards and one engine.
	static var gripen: Model {
		fighterBody(length: 25, width: 4, canopy: 4.2, engines: 1)
		+ Model(swept(span: 12.5, root: 13, tip: 1.5, sweep: 5.5, x: -2.5, z: altitude + 1.8, tone: Tone.wing)
		+ swept(span: 4.5, root: 4, tip: 1.2, sweep: 1.7, x: 5, z: altitude + 2.5, tone: Tone.wing)
		+ [fin(x: -9, z: altitude + 3.5, chord: 4.5, height: 5, rake: 2.3, tone: Tone.wing)]
		+ stores(y: 10, x: -6, z: altitude + 1))
	}

	/// F-35: broad angular body, trapezoid wings and twin fins around a single nozzle.
	static var f35: Model {
		fighterBody(length: 26, width: 6.8, canopy: 4, engines: 1)
		+ Model(swept(span: 12.5, root: 10, tip: 3.7, sweep: 4.2, x: -1, z: altitude + 2.2, tone: Tone.wing)
		+ swept(span: 5.8, root: 5.5, tip: 2.5, sweep: 2.4, x: -10, z: altitude + 2, tone: Tone.wing)
		+ sides(3) { fin(x: -9.5, y: $0, z: altitude + 4, chord: 4.5, height: 4.2, rake: 2.5, tone: Tone.wing) },
		lines: wingSeams(span: 12.5, root: 10, sweep: 4.2, tip: 3.7, x: -1, z: altitude + 3.15))
	}

	static var su57: Model {
		fighterBody(length: 30, width: 7, canopy: 4.5, engines: 2)
		+ Model(swept(span: 15.5, root: 14, tip: 3.5, sweep: 6, x: -0.5, z: altitude + 2.5, tone: Tone.wing)
		+ swept(span: 7, root: 6, tip: 2.5, sweep: 3, x: -11, z: altitude + 2.5, tone: Tone.wing)
		+ sides(3.2) { fin(x: -10.5, y: $0, z: altitude + 4, chord: 4.5, height: 3.4, rake: 2.5, tone: Tone.wing) },
		lines: wingSeams(span: 15.5, root: 14, sweep: 6, tip: 3.5, x: -0.5, z: altitude + 3.45))
	}

	static var su27: Model {
		fighterBody(length: 31, width: 5.8, canopy: 5, engines: 2)
		+ Model(swept(span: 16, root: 13.5, tip: 2.5, sweep: 5.5, x: 0, z: altitude + 1.8, tone: Tone.wing)
		+ swept(span: 7, root: 6.5, tip: 2.2, sweep: 2.5, x: -11, z: altitude + 1.8, tone: Tone.wing)
		+ sides(2.4) { fin(x: -10.8, y: $0, z: altitude + 4, chord: 5, height: 5.3, rake: 2.6, tone: Tone.wing) }
		+ stores(y: 11.5, x: -4.5, z: altitude + 1))
	}

	static var su25: Model {
		fighterBody(length: 25, width: 4.8, canopy: 5, engines: 2)
		+ Model(swept(span: 13.5, root: 7.5, tip: 3.5, sweep: 3, x: -1.5, z: altitude + 1.8, tone: Tone.wing)
		+ swept(span: 5.5, root: 4, tip: 1.5, sweep: 1.5, x: -10, z: altitude + 2, tone: Tone.wing)
		+ [fin(x: -9.5, z: altitude + 3.5, chord: 5, height: 5.2, rake: 2, tone: Tone.wing)]
		+ stores(y: 7.5, x: -2.5, z: altitude + 1) + stores(y: 11.5, x: -3.5, z: altitude + 1))
	}

	/// A-10: straight wings, high rear nacelles and two fins on a broad tailplane.
	static var a10: Model {
		let deck = altitude
		return Model([
			fuselage(length: 26, width: 4.3, z: deck + 1 ... deck + 4.8, x: 0,
				nose: 3, tail: 4, tone: Tone.body),
			fuselage(length: 6, width: 3.2, z: deck + 4 ... deck + 6.5, x: 6,
				nose: 2, tail: 1, tone: Tone.glass),
		] + sides(4) { cylinder(at: at(-7.5, $0, deck + 5.3), radius: 1.7, length: 7, axis: .x, tone: Tone.boom) }
		+ sides(4) { cylinder(at: at(-11.1, $0, deck + 5.3), radius: 1.1, length: 0.3, axis: .x, tone: Tone.blade) }
		+ swept(span: 16, root: 6, tip: 3.8, sweep: 0.8, x: 0, z: deck + 1.8, tone: Tone.wing)
		+ swept(span: 6.5, root: 4.5, tip: 2.5, sweep: 0.8, x: -11, z: deck + 2.3, tone: Tone.wing)
		+ sides(5) { fin(x: -11, y: $0, z: deck + 2.8, chord: 3.8, height: 4, rake: 1.5, tone: Tone.wing) }
		+ stores(y: 8, x: -1, z: deck + 1) + stores(y: 13, x: -2, z: deck + 1))
	}

	static var tornado: Model {
		fighterBody(length: 27, width: 5, canopy: 5.5, engines: 2)
		+ Model(swept(span: 12, root: 9, tip: 2.3, sweep: 7, x: -2, z: altitude + 2, tone: Tone.wing)
		+ swept(span: 5.5, root: 4.8, tip: 1.8, sweep: 2.7, x: -10.5, z: altitude + 2, tone: Tone.wing)
		+ [fin(x: -9.5, z: altitude + 3.5, chord: 6, height: 6, rake: 2.5, tone: Tone.wing)]
		+ stores(y: 8, x: -5.5, z: altitude + 1))
	}
}

extension Aircraft {

	static func rotorcraft(length: Float, width: Float, height: Float, rotor: Float, tail: Float,
		skids: Bool, glazed: Bool = true) -> Model {
		let deck = altitude
		let tailEnd = -length / 2 - tail + 3
		var solids = [
			fuselage(length: length, width: width, z: deck ... deck + height, x: 1,
				nose: 3, tail: 2, tone: Tone.body),
			fuselage(length: tail + 2, width: 1.6, z: deck + 3 ... deck + 4.5,
				x: tailEnd + tail / 2, nose: 0, tail: 2, tone: Tone.boom),
			fin(x: tailEnd + 1.5, z: deck + 4, chord: 3, height: 4, rake: 1.5, tone: Tone.boom),
			cylinder(at: at(-1, 0, deck + height + 1), radius: 0.7, length: 2, axis: .z, tone: Tone.gear),
		]
		if glazed {
			solids.append(fuselage(length: length * 0.45, width: width - 0.6,
				z: deck + 2 ... deck + height + 0.1, x: length * 0.28,
				nose: 2.5, tail: 0.5, tone: Tone.glass))
		}
		solids += sides(width * 0.23) {
			cylinder(at: at(-2, $0, deck + height + 0.3), radius: 0.8, length: 4.5, axis: .x, tone: Tone.boom)
		}
		var lines = Line.rotor(at: at(-1, 0, deck + height + 2.1), radius: rotor, tone: Tone.blade)
		lines += tailRotor(x: tailEnd, z: deck + 5.5, radius: 2)
		if skids {
			lines += sides(width / 2 + 0.8) { Line(from: at(-4, $0, deck - 1.5), to: at(4, $0, deck - 1.5), tone: Tone.gear) }
			lines += [-2, 2].flatMap { x in
				sides(width / 2 + 0.8) { Line(from: at(x, $0, deck), to: at(x, $0, deck - 1.5), tone: Tone.gear) }
			}
		} else {
			solids += sides(width / 2 + 1) {
				cylinder(at: at(-3, $0, deck - 1), radius: 0.8, length: 0.8, axis: .y, tone: Tone.gear)
			}
			solids.append(cylinder(at: at(length / 2 - 1, 0, deck - 1), radius: 0.7, length: 0.8, axis: .y, tone: Tone.gear))
			lines += sides(width / 2 + 1) { Line(from: at(-3, $0, deck - 1), to: at(-3, $0 - ($0 > 0 ? 1 : -1), deck + 1), tone: Tone.gear) }
		}
		return Model(solids, lines: lines)
	}

	static func fighterBody(length: Float, width: Float, canopy: Float, engines: Int) -> Model {
		let deck = altitude
		var solids = [
			fuselage(length: length, width: width, z: deck + 1 ... deck + 4.5, x: 0.5,
				nose: 5, tail: 0.5, tone: Tone.body),
			fuselage(length: canopy + 1.5, width: min(width - 0.5, 3.4),
				z: deck + 4 ... deck + 6.4, x: 4.5, nose: 2, tail: 1, tone: Tone.glass),
		]
		let rear = -length / 2 + 2
		let positions: [Float] = engines == 1 ? [0] : [-2, 2]
		for y in positions {
			solids += [
				cylinder(at: at(rear + 4, y, deck + 2.8), radius: engines == 1 ? 1.5 : 1.3,
					length: 9, axis: .x, tone: Tone.boom),
				cylinder(at: at(rear - 0.6, y, deck + 2.8), radius: 1, length: 0.3, axis: .x, tone: Tone.blade),
			]
		}
		solids += sides(width / 2) {
			armour(length: 4, width: 1.5, z: deck + 1 ... deck + 3.5, x: 1, y: $0,
				front: 0.8, corner: 0.3, tone: Tone.gear)
		}
		return Model(solids, lines: [
			Line(from: at(3, 0, deck + 6.4), to: at(6, 0, deck + 5), tone: Tone.boom),
		])
	}
}
