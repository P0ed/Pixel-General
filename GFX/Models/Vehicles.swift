public extension Units {

	/// M113 carrier: five road wheels, a raked bow and roof hatches over the troop bay.
	static var m113: Model {
		tracked(length: 30, width: 18, count: 5)
		+ Model([
			armour(length: 28.5, width: 15.75, z: 5.7 ... 12.3, x: -0.75,
				front: 6, rear: 0.75, side: 0.75, corner: 1.05, tone: Tone.body),
			hatch(x: -7.5, y: 2.55, z: 12.3, radius: 2.25),
			hatch(x: -2.25, y: 2.55, z: 12.3, radius: 2.25),
			cylinder(at: at(3, -2.55, 13.2), radius: 2.25, length: 1.8, axis: .z, tone: Tone.turret),
			barrel(from: at(3, -2.55, 13.95), to: at(10.5, -2.55, 14.4), caliber: 1.35, tone: Tone.barrel),
		], lines: grille(x: -7.5, y: -3.3, z: 12.375, length: 6, width: 4.5) + [
			Line(from: at(-9, 6, 12.15), to: at(-10.5, 6, 18), tone: Tone.antenna),
		])
	}

	/// Scout car with separate tyres, cabin glazing, a bonnet and a telescopic observation head.
	static var fennek: Model {
		wheeled(at: [-11.25, 10.8], width: 15, radius: 3.45)
		+ Model([
			armour(length: 33, width: 14.7, z: 4.95 ... 9.9,
				front: 3.9, rear: 1.05, side: 0.75, corner: 1.2, tone: Tone.body),
			armour(length: 18, width: 13.95, z: 9 ... 14.4, x: -6,
				front: 3, rear: 0.75, side: 0.9, corner: 1.05, tone: Tone.body),
			wedge(length: 3, width: 11.7, z: 10.8 ... 14.475, x: 1.5, rising: .xMinus, tone: 120),
			hatch(x: -4.5, z: 14.4, radius: 2.1),
			cylinder(at: at(-11.25, 0, 16.8), radius: 1.05, length: 4.8, axis: .z, tone: Tone.barrel),
			armour(length: 4.2, width: 4.95, z: 19.2 ... 21, x: -11.25, corner: 0.75, tone: Tone.turret),
			box(length: 0.6, width: 3, z: 19.5 ... 20.55, x: -9, tone: 75),
		] + sides(6.525) {
			box(length: 6.75, width: 0.375, z: 10.8 ... 13.2, x: -3.75, y: $0, tone: Tone.glass)
		}, lines: grille(x: 9, z: 9.975, length: 4.5, width: 6, tone: 125) + [
			Line(from: at(0.3, 0, 14.4), to: at(2.7, 0, 11.25), tone: Tone.body),
			Line(from: at(-12, 4.5, 14.1), to: at(-13.5, 4.5, 19.8), tone: Tone.antenna),
		] + sides(6.75) {
			Line(from: at(-3, $0, 6.75), to: at(-3, $0, 10.65), tone: 100)
		})
	}

	/// BRDM-2: a faceted boat-shaped hull, four tyres and the small auxiliary belly wheels.
	static var brdm2: Model {
		wheeled(at: [-11.25, 10.5], width: 15, radius: 3.3)
		+ wheeled(at: [-2.7, 2.7], width: 13.2, radius: 1.8)
		+ Model([
			armour(length: 34.5, width: 15, z: 4.8 ... 11.7,
				front: 9, rear: 1.5, side: 1.2, corner: 2.1, tone: Tone.body),
			hatch(x: -10.5, y: -2.55, z: 11.7),
		] + sides(3) {
			box(length: 1.5, width: 3, z: 10.8 ... 11.7, x: 6.6, y: $0, tone: 100)
		}, lines: grille(x: -10.5, y: 2.7, z: 11.775, length: 4.5, width: 3.75))
		+ turret(length: 8.25, width: 8.25, z: 11.85 ... 15.3, x: -0.75,
			front: 1.5, rear: 0.9, side: 1.35, corner: 1.8)
		+ cannon(from: at(2.25, 0, 13.8), to: at(15, 0, 14.25), caliber: 1.65)
	}

	/// Boxer: four axles below the high troop compartment, with a compact remote turret.
	static var boxer: Model {
		wheeled(at: [-12.75, -4.5, 4.5, 12.75], width: 17.25, radius: 3.225)
		+ Model([
			armour(length: 37.5, width: 17.25, z: 6 ... 12.9,
				front: 7.2, rear: 0.75, side: 1.05, corner: 1.8, tone: Tone.body),
			hatch(x: -11.25, y: 3.75, z: 12.9, radius: 1.95),
			hatch(x: 8.25, y: -3, z: 12.9),
		], lines: grille(x: -11.25, y: -3, z: 12.975, length: 4.5, width: 4.5) + [
			Line(from: at(-6, 7.2, 12), to: at(-7.2, 7.2, 18), tone: Tone.antenna),
		])
		+ turret(length: 9.75, width: 9.75, z: 13.2 ... 16.95, x: -2.25, corner: 2.1)
		+ cannon(from: at(1.5, 0, 15), to: at(17.25, 0, 15.75), caliber: 1.8)
	}

	/// Strf 9040: exposed six-wheel suspension, sloped glacis and an autocannon turret.
	static var strf90: Model {
		tracked(length: 33, width: 18.75, count: 6)
		+ Model([
			armour(length: 31.5, width: 16.5, z: 5.7 ... 11.25,
				front: 6.75, rear: 0.75, side: 0.75, corner: 1.35, tone: Tone.body),
			hatch(x: -10.5, y: 3, z: 11.25, radius: 2.1),
			hatch(x: 6.75, y: -3, z: 11.25),
			box(length: 5.25, width: 2.25, z: 12.3 ... 14.25, x: -2.25, y: -4.95, tone: Tone.cargo),
		], lines: grille(x: -9.75, y: -3.45, z: 11.325, length: 6, width: 4.5) + [
			Line(from: at(-6, 3.75, 15.3), to: at(-7.2, 3.75, 19.5), tone: Tone.antenna),
		])
		+ turret(length: 11.25, width: 10.5, z: 11.55 ... 15.6, x: -2.25,
			front: 2.25, rear: 0.75, side: 0.9, corner: 2.25)
		+ Model(hatch(x: -3, y: 2.1, z: 15.6))
		+ cannon(from: at(2.55, 0, 13.8), to: at(21.75, 0, 14.55), caliber: 1.8)
	}

	/// Six-wheel cargo truck: glazed cab, bumper and a canvas cover with visible support bows.
	static var manKat1: Model {
		truckChassis + truckCab + Model([
			armour(length: 21.75, width: 15.75, z: 7.2 ... 17.25, x: -7.5,
				side: 1.8, corner: 0.75, tone: Tone.cargo),
			box(length: 22.5, width: 16.5, z: 6.3 ... 7.5, x: -7.5, tone: Tone.turret),
		], lines: [-15, -9.75, -4.5, 0].flatMap { x in
			[
				Line(from: at(x, -7.8, 8.25), to: at(x, -6.15, 17.25), tone: 150),
				Line(from: at(x, -6.15, 17.25), to: at(x, 6.15, 17.25), tone: 215),
				Line(from: at(x, 6.15, 17.25), to: at(x, 7.8, 8.25), tone: 150),
			]
		})
	}

	/// M142 HIMARS: a single six-cell launcher above the cab-over FMTV chassis.
	static var m142: Model {
		truckChassis + truckCab + Model([
			box(length: 22.5, width: 15, z: 6.45 ... 7.8, x: -7.5, tone: Tone.turret),
			cylinder(at: at(-6, 0, 9), radius: 3, length: 10.5, axis: .y, tone: Tone.running),
			barrel(from: at(-3, 0, 7.5), to: at(-10.5, 0, 15), caliber: 2.25, tone: Tone.barrel),
		]) + rocketPod(from: at(-15, 0, 9.75), to: at(2.25, 0, 21.75), rows: 2, columns: 3, spacing: 3.6)
	}

	/// Self-propelled howitzer: seven wheels, angular fighting compartment and a raised gun tube.
	static var pzh2000: Model {
		tracked(length: 37.5, width: 19.5, count: 7)
		+ Model([
			armour(length: 36, width: 17.25, z: 5.7 ... 9.75,
				front: 6, rear: 0.9, side: 0.75, corner: 1.35, tone: Tone.body),
			hatch(x: 9, y: -3, z: 9.75),
		], lines: grille(x: 7.5, y: 3.3, z: 9.825, length: 4.5, width: 4.5))
		+ turret(length: 19.5, width: 15, z: 10.05 ... 18, x: -5.25,
			front: 2.7, rear: 0.75, side: 0.9, corner: 2.1)
		+ Model([
			hatch(x: -6.75, y: 2.7, z: 18, radius: 2.1),
			armour(length: 4.5, width: 6, z: 12 ... 16.5, x: 3.75, front: 0.75, corner: 0.75, tone: Tone.turret),
		], lines: [Line(from: at(-9, -4.5, 17.7), to: at(-10.5, -4.5, 23.25), tone: Tone.antenna)])
		+ cannon(from: at(4.5, 0, 14.4), to: at(30, 0, 29.25), caliber: 2.4, muzzle: true)
	}

	/// Towed howitzer: two round wheels, split trails, breech and an elevated barrel with muzzle brake.
	static var fh70: Model {
		let trails = sides(1) { sign in
			prism([(-19.5, sign * 7.2 - 0.9), (-3, sign * 2.7 - 0.9),
				(-3, sign * 2.7 + 0.9), (-19.5, sign * 7.2 + 0.9)], z: 1.2 ... 3, tone: Tone.running)
		}
		return wheeled(at: [0], width: 13.5, radius: 3.45) + Model(trails + [
			cylinder(at: at(-1.2, 0, 6), radius: 3, length: 3, axis: .z, tone: Tone.turret),
			armour(length: 7.5, width: 8.25, z: 5.7 ... 9.75, x: -1.5, front: 1.05, corner: 0.9, tone: Tone.turret),
			barrel(from: at(-4.5, 0, 5.1), to: at(6, 0, 12.3), caliber: 3.9, tone: Tone.turret),
		] + sides(4.8) {
			armour(length: 2.25, width: 5.7, z: 5.25 ... 11.7, x: 1.5, y: $0,
				front: 0.9, side: 0.45, corner: 0.6, tone: Tone.body)
		} + sides(7.2) {
			box(length: 3.75, width: 3.75, z: 0 ... 1.8, x: -18, y: $0, tone: Tone.turret)
		}) + cannon(from: at(3, 0, 10.2), to: at(27, 0, 26.7), caliber: 2.1, muzzle: true)
	}

	/// Tracked anti-air: faceted radar head, two raised autocannons and exposed road wheels.
	static var gepard: Model {
		tracked(length: 34.5, width: 19.5, count: 7)
		+ Model([
			armour(length: 33, width: 17.25, z: 5.7 ... 9.3,
				front: 6, rear: 0.75, side: 0.75, corner: 1.2, tone: Tone.body),
			cylinder(at: at(-7.5, 0, 17.25), radius: 1.05, length: 4.5, axis: .z, tone: Tone.barrel),
			armour(length: 2.7, width: 11.25, z: 16.95 ... 22.2, x: -7.5,
				front: 0.45, side: 0.75, corner: 0.75, tone: Tone.cargo),
		], lines: grille(x: -10.5, y: 3, z: 9.375, length: 4.5, width: 4.5) + [
			Line(from: at(-6.075, -3.9, 18.15), to: at(-6.075, 3.9, 18.15), tone: 125),
			Line(from: at(-6.075, -3.9, 20.25), to: at(-6.075, 3.9, 20.25), tone: 125),
		]) + turret(length: 13.5, width: 13.5, z: 9.6 ... 15.3, x: -2.25, front: 1.95, corner: 2.25)
		+ Model(sides(4.65) {
			barrel(from: at(1.5, $0, 13.2), to: at(21, $0, 18.75), caliber: 1.8, tone: Tone.barrel)
		})
	}

	/// Bofors: circular turntable, split shields, raised breech, sight and folding wheels.
	static var boforsL70: Model {
		Model([
			box(length: 31.5, width: 3, z: 1.2 ... 3, x: -2.25, tone: Tone.running),
			box(length: 3.75, width: 28.5, z: 1.2 ... 3, tone: Tone.running),
			cylinder(at: at(0, 0, 3.75), radius: 5.1, length: 2.25, axis: .z, tone: Tone.turret),
			armour(length: 7.5, width: 7.5, z: 4.5 ... 9.75, front: 1.05, corner: 1.2, tone: Tone.turret),
			barrel(from: at(-3, 0, 10.5), to: at(13.5, 0, 34.5), caliber: 2.25, tone: Tone.barrel),
			barrel(from: at(-3, 0, 10.5), to: at(2.25, 0, 18.15), caliber: 4.2, tone: Tone.turret),
			box(length: 4.5, width: 3.75, z: 6.45 ... 7.5, x: -6.75, y: 5.25, tone: Tone.turret),
		] + sides(5.25) {
			armour(length: 3.45, width: 5.7, z: 7.5 ... 15.75, x: 1.5, y: $0,
				front: 1.2, side: 0.6, corner: 0.75, tone: Tone.body)
		} + sides(9) {
			cylinder(at: at(-8.25, $0, 3), radius: 3, length: 1.95, axis: .y, tone: 44)
		} + sides(10.05) {
			cylinder(at: at(-8.25, $0, 3), radius: 1.5, length: 0.45, axis: .y, tone: 125)
		} + sides(13.5) {
			box(length: 4.5, width: 4.5, z: 0 ... 1.8, y: $0, tone: Tone.turret)
		} + [-18, 13.5].map {
			box(length: 4.5, width: 4.5, z: 0 ... 1.8, x: $0, tone: Tone.turret)
		}, lines: [
			Line(from: at(-3, -3.75, 10.5), to: at(3, -3.75, 18), tone: Tone.antenna),
			Line(from: at(1.5, -5.25, 16.8), to: at(4.5, -2.25, 16.8), tone: Tone.antenna),
			Line(from: at(3, -3.75, 15.3), to: at(3, -3.75, 18.3), tone: Tone.antenna),
			Line(from: at(2.25, 0, 18.9), to: at(13.05, 0, 34.65), tone: Tone.barrel),
		])
	}
}

extension Units {

	static func wheeled(at positions: [Float], width: Float, radius: Float) -> Model {
		var solids: [Solid] = []
		for x in positions {
			solids.append(box(length: 1.5, width: width, z: radius - 0.45 ... radius + 0.45, x: x, tone: Tone.running))
			for sign: Float in [-1, 1] {
				let y = sign * (width / 2 + 0.15)
				solids += [
					cylinder(at: at(x, y, radius), radius: radius, length: 2.1, axis: .y, tone: 42),
					cylinder(at: at(x, y + sign * 1.125, radius), radius: radius * 0.6, length: 0.3, axis: .y, tone: 110),
					cylinder(at: at(x, y + sign * 1.35, radius), radius: radius * 0.25, length: 0.3, axis: .y, tone: Tone.barrel),
				]
			}
		}
		return Model(solids)
	}

	static func tracked(length: Float, width: Float, count: Int) -> Model {
		var solids = sides((width - 3.9) / 2) { y in
			var track = box(length: length, width: 3.9, z: 0 ... 7.2, y: y, tone: 36)
			for sign: Float in [-1, 1] {
				track.planes += [
					Plane(normal: V3(sign, 0, -1), through: at(sign * length / 2, y, 1.8)),
					Plane(normal: V3(sign, 0, 1), through: at(sign * length / 2, y, 5.4)),
				]
			}
			return track
		}
		for sign: Float in [-1, 1] {
			for index in 0 ..< count {
				let x = (Float(index) / Float(count - 1) - 0.5) * (length - 6)
				let y = sign * width / 2
				solids += [
					cylinder(at: at(x, y, 3.6), radius: 2.475, length: 0.9, axis: .y, tone: 44),
					cylinder(at: at(x, y + sign * 0.525, 3.6), radius: 1.8, length: 0.3, axis: .y, tone: 110),
					cylinder(at: at(x, y + sign * 0.75, 3.6), radius: 0.75, length: 0.3, axis: .y, tone: Tone.barrel),
				]
			}
			solids.append(armour(length: length - 1.5, width: 4.2, z: 7.2 ... 7.95,
				y: sign * (width - 3.9) / 2, front: 0.75, rear: 0.75, corner: 0.6, tone: Tone.body))
		}
		return Model(solids)
	}

	static var truckChassis: Model {
		wheeled(at: [-13.5, -4.5, 12], width: 15, radius: 3.3) + Model([
			box(length: 39, width: 12, z: 3.6 ... 6.6, tone: Tone.running),
			box(length: 7.5, width: 2.25, z: 4.5 ... 6.75, x: 2.25, y: 6.75, tone: Tone.turret),
		])
	}

	static var truckCab: Model {
		Model([
			armour(length: 12.75, width: 15, z: 6 ... 15.75, x: 12,
				front: 1.2, rear: 0.45, side: 0.6, corner: 0.75, tone: Tone.body),
			box(length: 0.45, width: 11.1, z: 11.55 ... 14.25, x: 17.85, tone: 110),
			box(length: 0.6, width: 6.75, z: 7.5 ... 10.05, x: 18.3, tone: Tone.running),
			box(length: 1.8, width: 16.05, z: 5.4 ... 6.45, x: 18, tone: Tone.turret),
		] + sides(7.2) {
			box(length: 5.25, width: 0.3, z: 10.95 ... 14.25, x: 12, y: $0, tone: Tone.glass)
		} + sides(5.4) {
			box(length: 0.75, width: 1.5, z: 8.4 ... 9.75, x: 18.3, y: $0, tone: 220)
		}, lines: [
			Line(from: at(18.075, 0, 11.55), to: at(17.925, 0, 14.25), tone: Tone.body),
		] + sides(7.35) {
			Line(from: at(8.25, $0, 7.2), to: at(8.25, $0, 12), tone: 115)
		})
	}

	static func cannon(from start: V3, to end: V3, caliber: Float, muzzle: Bool = false) -> Model {
		let axis = (end - start).normalized
		var solids = [
			barrel(from: start, to: end, caliber: caliber, tone: Tone.barrel),
			barrel(from: start, to: start + axis * 4.5, caliber: caliber * 1.5, tone: Tone.turret),
		]
		if muzzle {
			solids.append(barrel(from: end - axis * 2.7, to: end, caliber: caliber * 1.6, tone: Tone.turret))
		}
		return Model(solids, lines: [
			Line(from: start + axis * 4.5 + V3(0, 0, caliber / 2),
				to: end - axis * 1.05 + V3(0, 0, caliber / 2), tone: Tone.barrel),
		])
	}
}
