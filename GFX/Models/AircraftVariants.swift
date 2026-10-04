public extension Aircraft {

	/// Little Bird: compact glazed bubble cabin, exposed skids and a small rotor disc.
	static var mh6: Model {
		rotorcraft(length: 15, width: 8.7, height: 7.95, rotor: 16.5, tail: 15, skids: true)
		+ Model([
			box(length: 7.5, width: 2.25, z: altitude - 0.75 ... altitude + 0.3, x: -1.5, y: -6.15, tone: Tone.gear),
			box(length: 7.5, width: 2.25, z: altitude - 0.75 ... altitude + 0.3, x: -1.5, y: 6.15, tone: Tone.gear),
		])
	}

	/// Mi-8: long transport cabin, multiple side windows and wheeled landing gear.
	static var mi8: Model {
		rotorcraft(length: 28.5, width: 12, height: 9.75, rotor: 24, tail: 15, skids: false)
		+ Model(lines: [-7.5, -3, 1.5].flatMap { x in
			sides(6.075) { Line(from: at(x, $0, altitude + 4.5), to: at(x + 1.5, $0, altitude + 6), tone: Tone.glass, width: 2) }
		})
	}

	/// Mi-24: stepped tandem canopy, stub wings, rocket pods and a chin gun.
	static var mi24: Model {
		rotorcraft(length: 27, width: 10.2, height: 9, rotor: 22.5, tail: 15, skids: false)
		+ Model([
			fuselage(length: 7.5, width: 5.7, z: altitude + 4.5 ... altitude + 9.75, x: 4.5,
				nose: 2.25, tail: 1.5, tone: Tone.glass),
			fuselage(length: 6.75, width: 5.25, z: altitude + 2.25 ... altitude + 6.45, x: 10.5,
				nose: 2.7, tail: 0.75, tone: Tone.glass),
			cylinder(at: at(11.25, 0, altitude), radius: 1.5, length: 2.25, axis: .z, tone: Tone.gear),
			barrel(from: at(11.25, 0, altitude), to: at(18, 0, altitude), caliber: 1.05, tone: Tone.gear),
		] + swept(span: 11.25, root: 7.5, tip: 3, sweep: 2.25, x: -2.25, z: altitude + 3, tone: Tone.wing)
		+ sides(9.75) { cylinder(at: at(-3, $0, altitude + 1.5), radius: 1.8, length: 7.5, axis: .x, tone: Tone.gear) })
	}

	static var skeldarm: Model {
		skeldar + Model(swept(span: 6, root: 4.5, tip: 2.25, sweep: 0.75, x: 0, z: altitude + 1.5, tone: Tone.wing)
		+ stores(y: 5.25, x: 0, z: altitude))
	}

	static var mq8: Model {
		rotorcraft(length: 18.75, width: 8.25, height: 6.75, rotor: 18.75, tail: 13.5, skids: true, glazed: false)
		+ Model([
			cylinder(at: at(6, 0, altitude - 0.75), radius: 1.95, length: 2.25, axis: .z, tone: Tone.glass),
		] + swept(span: 6, root: 4.5, tip: 1.5, sweep: 1.5, x: -18, z: altitude + 5.25, tone: Tone.wing))
	}

	/// Spherical cabin and two coaxial rotors; no tail rotor or boom.
	static var ka137: Model {
		Model([
			fuselage(length: 10.5, width: 9, z: altitude + 1.5 ... altitude + 9, x: 0,
				nose: 3, tail: 3, tone: Tone.body),
			cylinder(at: at(3, 0, altitude + 0.75), radius: 1.65, length: 2.25, axis: .z, tone: Tone.glass),
			cylinder(at: at(0, 0, altitude + 10.5), radius: 0.9, length: 6, axis: .z, tone: Tone.gear),
		], lines: Line.rotor(at: at(0, 0, altitude + 9.75), radius: 15, tone: Tone.blade)
			+ Line.rotor(at: at(0, 0, altitude + 13.5), radius: 13.5, tone: Tone.blade)
			+ sides(4.5) { Line(from: at(-3, $0, altitude - 1.5), to: at(3, $0, altitude - 1.5), tone: Tone.gear) }
			+ sides(4.5) { Line(from: at(0, $0, altitude + 1.5), to: at(0, $0, altitude - 1.5), tone: Tone.gear) })
	}

	static var orlan: Model {
		let deck = altitude + 1.5
		return Model([
			fuselage(length: 24, width: 3.75, z: deck ... deck + 4.5, x: 0,
				nose: 3.75, tail: 9, tone: Tone.body),
			fin(x: -9, z: deck + 3, chord: 3.75, height: 5.25, rake: 1.5, tone: Tone.wing),
		] + swept(span: 16.5, root: 5.25, tip: 3.45, sweep: 1.2, x: 2.25, z: deck + 3.6, tone: Tone.wing)
		+ swept(span: 6, root: 3.75, tip: 2.1, sweep: 1.2, x: -9.45, z: deck + 2.7, tone: Tone.wing),
		lines: [Line(from: at(12.45, -3.75, deck + 2.25), to: at(12.45, 3.75, deck + 2.25), tone: Tone.blade)])
	}

	static var bayraktar: Model {
		let deck = altitude + 1.5
		return Model([
			fuselage(length: 31.5, width: 4.95, z: deck ... deck + 5.25, x: 0,
				nose: 6, tail: 9, tone: Tone.body),
			cylinder(at: at(7.5, 0, deck - 0.75), radius: 1.5, length: 2.25, axis: .z, tone: Tone.glass),
		] + swept(span: 21, root: 4.95, tip: 2.7, sweep: 0.6, x: 0, z: deck + 3.9, tone: Tone.wing)
		+ swept(span: 6.75, root: 4.95, tip: 2.25, sweep: 2.25, x: -12.75, z: deck + 2.25, tone: Tone.wing)
		+ sides(4.2) { fin(x: -13.05, y: $0, z: deck + 2.25, chord: 3.75, height: 3.6, rake: 2.1, tone: Tone.wing) }
		+ stores(y: 10.5, x: -0.75, z: deck + 2.7), lines: [
			Line(from: at(-7.5, -4.5, deck + 3), to: at(-7.5, 4.5, deck + 3), tone: Tone.blade),
		])
	}

	/// Gripen's silhouette is a delta wing with separate forward canards and one engine.
	static var gripen: Model {
		fighterBody(length: 37.5, width: 6, canopy: 6.3, engines: 1)
		+ Model(swept(span: 18.75, root: 19.5, tip: 2.25, sweep: 8.25, x: -3.75, z: altitude + 2.7, tone: Tone.wing)
		+ swept(span: 6.75, root: 6, tip: 1.8, sweep: 2.55, x: 7.5, z: altitude + 3.75, tone: Tone.wing)
		+ [fin(x: -13.5, z: altitude + 5.25, chord: 6.75, height: 7.5, rake: 3.45, tone: Tone.wing)]
		+ stores(y: 15, x: -9, z: altitude + 1.5))
	}

	/// F-35: broad angular body, trapezoid wings and twin fins around a single nozzle.
	static var f35: Model {
		fighterBody(length: 39, width: 10.2, canopy: 6, engines: 1)
		+ Model(swept(span: 18.75, root: 15, tip: 5.55, sweep: 6.3, x: -1.5, z: altitude + 3.3, tone: Tone.wing)
		+ swept(span: 8.7, root: 8.25, tip: 3.75, sweep: 3.6, x: -15, z: altitude + 3, tone: Tone.wing)
		+ sides(4.5) { fin(x: -14.25, y: $0, z: altitude + 6, chord: 6.75, height: 6.3, rake: 3.75, tone: Tone.wing) },
		lines: wingSeams(span: 18.75, root: 15, sweep: 6.3, tip: 5.55, x: -1.5, z: altitude + 4.725))
	}

	static var su57: Model {
		fighterBody(length: 45, width: 10.5, canopy: 6.75, engines: 2)
		+ Model(swept(span: 23.25, root: 21, tip: 5.25, sweep: 9, x: -0.75, z: altitude + 3.75, tone: Tone.wing)
		+ swept(span: 10.5, root: 9, tip: 3.75, sweep: 4.5, x: -16.5, z: altitude + 3.75, tone: Tone.wing)
		+ sides(4.8) { fin(x: -15.75, y: $0, z: altitude + 6, chord: 6.75, height: 5.1, rake: 3.75, tone: Tone.wing) },
		lines: wingSeams(span: 23.25, root: 21, sweep: 9, tip: 5.25, x: -0.75, z: altitude + 5.175))
	}

	static var su27: Model {
		fighterBody(length: 46.5, width: 8.7, canopy: 7.5, engines: 2)
		+ Model(swept(span: 24, root: 20.25, tip: 3.75, sweep: 8.25, x: 0, z: altitude + 2.7, tone: Tone.wing)
		+ swept(span: 10.5, root: 9.75, tip: 3.3, sweep: 3.75, x: -16.5, z: altitude + 2.7, tone: Tone.wing)
		+ sides(3.6) { fin(x: -16.2, y: $0, z: altitude + 6, chord: 7.5, height: 7.95, rake: 3.9, tone: Tone.wing) }
		+ stores(y: 17.25, x: -6.75, z: altitude + 1.5))
	}

	static var su25: Model {
		fighterBody(length: 37.5, width: 7.2, canopy: 7.5, engines: 2)
		+ Model(swept(span: 20.25, root: 11.25, tip: 5.25, sweep: 4.5, x: -2.25, z: altitude + 2.7, tone: Tone.wing)
		+ swept(span: 8.25, root: 6, tip: 2.25, sweep: 2.25, x: -15, z: altitude + 3, tone: Tone.wing)
		+ [fin(x: -14.25, z: altitude + 5.25, chord: 7.5, height: 7.8, rake: 3, tone: Tone.wing)]
		+ stores(y: 11.25, x: -3.75, z: altitude + 1.5) + stores(y: 17.25, x: -5.25, z: altitude + 1.5))
	}

	/// A-10: straight wings, high rear nacelles and two fins on a broad tailplane.
	static var a10: Model {
		let deck = altitude
		return Model([
			fuselage(length: 39, width: 6.45, z: deck + 1.5 ... deck + 7.2, x: 0,
				nose: 4.5, tail: 6, tone: Tone.body),
			fuselage(length: 9, width: 4.8, z: deck + 6 ... deck + 9.75, x: 9,
				nose: 3, tail: 1.5, tone: Tone.glass),
		] + sides(6) { cylinder(at: at(-11.25, $0, deck + 7.95), radius: 2.55, length: 10.5, axis: .x, tone: Tone.boom) }
		+ sides(6) { cylinder(at: at(-16.65, $0, deck + 7.95), radius: 1.65, length: 0.45, axis: .x, tone: Tone.blade) }
		+ swept(span: 24, root: 9, tip: 5.7, sweep: 1.2, x: 0, z: deck + 2.7, tone: Tone.wing)
		+ swept(span: 9.75, root: 6.75, tip: 3.75, sweep: 1.2, x: -16.5, z: deck + 3.45, tone: Tone.wing)
		+ sides(7.5) { fin(x: -16.5, y: $0, z: deck + 4.2, chord: 5.7, height: 6, rake: 2.25, tone: Tone.wing) }
		+ stores(y: 12, x: -1.5, z: deck + 1.5) + stores(y: 19.5, x: -3, z: deck + 1.5))
	}

	static var tornado: Model {
		fighterBody(length: 40.5, width: 7.5, canopy: 8.25, engines: 2)
		+ Model(swept(span: 18, root: 13.5, tip: 3.45, sweep: 10.5, x: -3, z: altitude + 3, tone: Tone.wing)
		+ swept(span: 8.25, root: 7.2, tip: 2.7, sweep: 4.05, x: -15.75, z: altitude + 3, tone: Tone.wing)
		+ [fin(x: -14.25, z: altitude + 5.25, chord: 9, height: 9, rake: 3.75, tone: Tone.wing)]
		+ stores(y: 12, x: -8.25, z: altitude + 1.5))
	}
}

extension Aircraft {

	static func rotorcraft(length: Float, width: Float, height: Float, rotor: Float, tail: Float,
		skids: Bool, glazed: Bool = true) -> Model {
		let deck = altitude
		let tailEnd = -length / 2 - tail + 4.5
		var solids = [
			fuselage(length: length, width: width, z: deck ... deck + height, x: 1.5,
				nose: 4.5, tail: 3, tone: Tone.body),
			fuselage(length: tail + 3, width: 2.4, z: deck + 4.5 ... deck + 6.75,
				x: tailEnd + tail / 2, nose: 0, tail: 3, tone: Tone.boom),
			fin(x: tailEnd + 2.25, z: deck + 6, chord: 4.5, height: 6, rake: 2.25, tone: Tone.boom),
			cylinder(at: at(-1.5, 0, deck + height + 1.5), radius: 1.05, length: 3, axis: .z, tone: Tone.gear),
		]
		if glazed {
			solids.append(fuselage(length: length * 0.45, width: width - 0.9,
				z: deck + 3 ... deck + height + 0.15, x: length * 0.28,
				nose: 3.75, tail: 0.75, tone: Tone.glass))
		}
		solids += sides(width * 0.23) {
			cylinder(at: at(-3, $0, deck + height + 0.45), radius: 1.2, length: 6.75, axis: .x, tone: Tone.boom)
		}
		var lines = Line.rotor(at: at(-1.5, 0, deck + height + 3.15), radius: rotor, tone: Tone.blade)
		lines += tailRotor(x: tailEnd, z: deck + 8.25, radius: 3)
		if skids {
			lines += sides(width / 2 + 1.2) { Line(from: at(-6, $0, deck - 2.25), to: at(6, $0, deck - 2.25), tone: Tone.gear) }
			lines += [-3, 3].flatMap { x in
				sides(width / 2 + 1.2) { Line(from: at(x, $0, deck), to: at(x, $0, deck - 2.25), tone: Tone.gear) }
			}
		} else {
			solids += sides(width / 2 + 1.5) {
				cylinder(at: at(-4.5, $0, deck - 1.5), radius: 1.2, length: 1.2, axis: .y, tone: Tone.gear)
			}
			solids.append(cylinder(at: at(length / 2 - 1.5, 0, deck - 1.5), radius: 1.05, length: 1.2, axis: .y, tone: Tone.gear))
			lines += sides(width / 2 + 1.5) { Line(from: at(-4.5, $0, deck - 1.5), to: at(-4.5, $0 - ($0 > 0 ? 1.5 : -1.5), deck + 1.5), tone: Tone.gear) }
		}
		return Model(solids, lines: lines)
	}

	static func fighterBody(length: Float, width: Float, canopy: Float, engines: Int) -> Model {
		let deck = altitude
		var solids = [
			fuselage(length: length, width: width, z: deck + 1.5 ... deck + 6.75, x: 0.75,
				nose: 7.5, tail: 0.75, tone: Tone.body),
			fuselage(length: canopy + 2.25, width: min(width - 0.75, 5.1),
				z: deck + 6 ... deck + 9.6, x: 6.75, nose: 3, tail: 1.5, tone: Tone.glass),
		]
		let rear = -length / 2 + 3
		let positions: [Float] = engines == 1 ? [0] : [-3, 3]
		for y in positions {
			solids += [
				cylinder(at: at(rear + 6, y, deck + 4.2), radius: engines == 1 ? 2.25 : 1.95,
					length: 13.5, axis: .x, tone: Tone.boom),
				cylinder(at: at(rear - 0.9, y, deck + 4.2), radius: 1.5, length: 0.45, axis: .x, tone: Tone.blade),
			]
		}
		solids += sides(width / 2) {
			armour(length: 6, width: 2.25, z: deck + 1.5 ... deck + 5.25, x: 1.5, y: $0,
				front: 1.2, corner: 0.45, tone: Tone.gear)
		}
		return Model(solids, lines: [
			Line(from: at(4.5, 0, deck + 9.6), to: at(9, 0, deck + 7.5), tone: Tone.boom),
		])
	}
}
