public extension Units {

	/// M113-style carrier: five road wheels, a raked bow and roof hatches over the troop bay.
	static var recon: Model {
		tracked(length: 20, width: 12, count: 5)
		+ Model([
			armour(length: 19, width: 10.5, z: 3.8 ... 8.2, x: -0.5,
				front: 4, rear: 0.5, side: 0.5, corner: 0.7, tone: Tone.body),
			hatch(x: -5, y: 1.7, z: 8.2, radius: 1.5),
			hatch(x: -1.5, y: 1.7, z: 8.2, radius: 1.5),
			cylinder(at: at(2, -1.7, 8.8), radius: 1.5, length: 1.2, axis: .z, tone: Tone.turret),
			barrel(from: at(2, -1.7, 9.3), to: at(7, -1.7, 9.6), caliber: 0.9, tone: Tone.barrel),
		], lines: grille(x: -5, y: -2.2, z: 8.25, length: 4, width: 3) + [
			Line(from: at(-6, 4, 8.1), to: at(-7, 4, 12), tone: Tone.antenna),
		])
	}

	/// Scout car with separate tyres, cabin glazing, a bonnet and a telescopic observation head.
	static var fennek: Model {
		wheeled(at: [-7.5, 7.2], width: 10, radius: 2.3)
		+ Model([
			armour(length: 22, width: 9.8, z: 3.3 ... 6.6,
				front: 2.6, rear: 0.7, side: 0.5, corner: 0.8, tone: Tone.body),
			armour(length: 12, width: 9.3, z: 6 ... 9.6, x: -4,
				front: 2, rear: 0.5, side: 0.6, corner: 0.7, tone: Tone.body),
			wedge(length: 2, width: 7.8, z: 7.2 ... 9.65, x: 1, rising: .xMinus, tone: 120),
			hatch(x: -3, z: 9.6, radius: 1.4),
			cylinder(at: at(-7.5, 0, 11.2), radius: 0.7, length: 3.2, axis: .z, tone: Tone.barrel),
			armour(length: 2.8, width: 3.3, z: 12.8 ... 14, x: -7.5, corner: 0.5, tone: Tone.turret),
			box(length: 0.4, width: 2, z: 13 ... 13.7, x: -6, tone: 75),
		] + sides(4.35) {
			box(length: 4.5, width: 0.25, z: 7.2 ... 8.8, x: -2.5, y: $0, tone: Tone.glass)
		}, lines: grille(x: 6, z: 6.65, length: 3, width: 4, tone: 125) + [
			Line(from: at(0.2, 0, 9.6), to: at(1.8, 0, 7.5), tone: Tone.body),
			Line(from: at(-8, 3, 9.4), to: at(-9, 3, 13.2), tone: Tone.antenna),
		] + sides(4.5) {
			Line(from: at(-2, $0, 4.5), to: at(-2, $0, 7.1), tone: 100)
		})
	}

	/// BRDM-2: a faceted boat-shaped hull, four tyres and the small auxiliary belly wheels.
	static var brdm2: Model {
		wheeled(at: [-7.5, 7], width: 10, radius: 2.2)
		+ wheeled(at: [-1.8, 1.8], width: 8.8, radius: 1.2)
		+ Model([
			armour(length: 23, width: 10, z: 3.2 ... 7.8,
				front: 6, rear: 1, side: 0.8, corner: 1.4, tone: Tone.body),
			hatch(x: -7, y: -1.7, z: 7.8),
		] + sides(2) {
			box(length: 1, width: 2, z: 7.2 ... 7.8, x: 4.4, y: $0, tone: 100)
		}, lines: grille(x: -7, y: 1.8, z: 7.85, length: 3, width: 2.5))
		+ turret(length: 5.5, width: 5.5, z: 7.9 ... 10.2, x: -0.5,
			front: 1, rear: 0.6, side: 0.9, corner: 1.2)
		+ cannon(from: at(1.5, 0, 9.2), to: at(10, 0, 9.5), caliber: 1.1)
	}

	/// Boxer: four axles below the high troop compartment, with a compact remote turret.
	static var carrier: Model {
		wheeled(at: [-8.5, -3, 3, 8.5], width: 11.5, radius: 2.15)
		+ Model([
			armour(length: 25, width: 11.5, z: 4 ... 8.6,
				front: 4.8, rear: 0.5, side: 0.7, corner: 1.2, tone: Tone.body),
			hatch(x: -7.5, y: 2.5, z: 8.6, radius: 1.3),
			hatch(x: 5.5, y: -2, z: 8.6),
		], lines: grille(x: -7.5, y: -2, z: 8.65, length: 3, width: 3) + [
			Line(from: at(-4, 4.8, 8), to: at(-4.8, 4.8, 12), tone: Tone.antenna),
		])
		+ turret(length: 6.5, width: 6.5, z: 8.8 ... 11.3, x: -1.5, corner: 1.4)
		+ cannon(from: at(1, 0, 10), to: at(11.5, 0, 10.5), caliber: 1.2)
	}

	/// CV90-style IFV: exposed six-wheel suspension, sloped glacis and an autocannon turret.
	static var ifv: Model {
		tracked(length: 22, width: 12.5, count: 6)
		+ Model([
			armour(length: 21, width: 11, z: 3.8 ... 7.5,
				front: 4.5, rear: 0.5, side: 0.5, corner: 0.9, tone: Tone.body),
			hatch(x: -7, y: 2, z: 7.5, radius: 1.4),
			hatch(x: 4.5, y: -2, z: 7.5),
			box(length: 3.5, width: 1.5, z: 8.2 ... 9.5, x: -1.5, y: -3.3, tone: Tone.cargo),
		], lines: grille(x: -6.5, y: -2.3, z: 7.55, length: 4, width: 3) + [
			Line(from: at(-4, 2.5, 10.2), to: at(-4.8, 2.5, 13), tone: Tone.antenna),
		])
		+ turret(length: 7.5, width: 7, z: 7.7 ... 10.4, x: -1.5,
			front: 1.5, rear: 0.5, side: 0.6, corner: 1.5)
		+ Model(hatch(x: -2, y: 1.4, z: 10.4))
		+ cannon(from: at(1.7, 0, 9.2), to: at(14.5, 0, 9.7), caliber: 1.2)
	}

	/// Six-wheel cargo truck: glazed cab, bumper and a canvas cover with visible support bows.
	static var truck: Model {
		truckChassis + truckCab + Model([
			armour(length: 14.5, width: 10.5, z: 4.8 ... 11.5, x: -5,
				side: 1.2, corner: 0.5, tone: Tone.cargo),
			box(length: 15, width: 11, z: 4.2 ... 5, x: -5, tone: Tone.turret),
		], lines: [-10, -6.5, -3, 0].flatMap { x in
			[
				Line(from: at(x, -5.2, 5.5), to: at(x, -4.1, 11.5), tone: 150),
				Line(from: at(x, -4.1, 11.5), to: at(x, 4.1, 11.5), tone: 215),
				Line(from: at(x, 4.1, 11.5), to: at(x, 5.2, 5.5), tone: 150),
			]
		})
	}

	/// Raised rocket pods on a truck bed: individual cell mouths, seams and a hydraulic cradle.
	static var launcher: Model {
		let start = at(-10, 0, 6.5), end = at(1.5, 0, 14.5)
		let pod = barrel(from: start, to: end, caliber: 7.5, tone: Tone.cargo)
		let axis = (end - start).normalized
		let across = V3(-axis.z, 0, axis.x)
		let lines = [-2, 0, 2].map { y in
			Line(from: start + V3(0, y, 0) + across * 3.75,
				to: end + V3(0, y, 0) + across * 3.75, tone: 115)
		}
		// The forward-facing elevated end displays six launcher cell openings.
		var mouths: [Solid] = []
		for y: Float in [-2.3, 0, 2.3] {
			for offset: Float in [-1.5, 1.5] {
				let center = end + V3(0, y, 0) + across * offset + axis * 0.1
				mouths.append(barrel(from: center - axis * 0.2, to: center + axis * 0.3, caliber: 1.1, tone: 50))
			}
		}
		return truckChassis + truckCab + Model([
			box(length: 15, width: 10, z: 4.3 ... 5.2, x: -5, tone: Tone.turret),
			cylinder(at: at(-4, 0, 6), radius: 2, length: 7, axis: .y, tone: Tone.running),
			barrel(from: at(-2, 0, 5), to: at(-7, 0, 10), caliber: 1.5, tone: Tone.barrel),
			pod,
		] + mouths, lines: lines)
	}

	/// Self-propelled howitzer: seven wheels, angular fighting compartment and a raised gun tube.
	static var artillery: Model {
		tracked(length: 25, width: 13, count: 7)
		+ Model([
			armour(length: 24, width: 11.5, z: 3.8 ... 6.5,
				front: 4, rear: 0.6, side: 0.5, corner: 0.9, tone: Tone.body),
			hatch(x: 6, y: -2, z: 6.5),
		], lines: grille(x: 5, y: 2.2, z: 6.55, length: 3, width: 3))
		+ turret(length: 13, width: 10, z: 6.7 ... 12, x: -3.5,
			front: 1.8, rear: 0.5, side: 0.6, corner: 1.4)
		+ Model([
			hatch(x: -4.5, y: 1.8, z: 12, radius: 1.4),
			armour(length: 3, width: 4, z: 8 ... 11, x: 2.5, front: 0.5, corner: 0.5, tone: Tone.turret),
		], lines: [Line(from: at(-6, -3, 11.8), to: at(-7, -3, 15.5), tone: Tone.antenna)])
		+ cannon(from: at(3, 0, 9.6), to: at(20, 0, 19.5), caliber: 1.6, muzzle: true)
	}

	/// Towed howitzer: two round wheels, split trails, breech and an elevated barrel with muzzle brake.
	static var gun: Model {
		let trails = sides(1) { sign in
			prism([(-13, sign * 4.8 - 0.6), (-2, sign * 1.8 - 0.6),
				(-2, sign * 1.8 + 0.6), (-13, sign * 4.8 + 0.6)], z: 0.8 ... 2, tone: Tone.running)
		}
		return wheeled(at: [0], width: 9, radius: 2.3) + Model(trails + [
			cylinder(at: at(-0.8, 0, 4), radius: 2, length: 2, axis: .z, tone: Tone.turret),
			armour(length: 5, width: 5.5, z: 3.8 ... 6.5, x: -1, front: 0.7, corner: 0.6, tone: Tone.turret),
			barrel(from: at(-3, 0, 3.4), to: at(4, 0, 8.2), caliber: 2.6, tone: Tone.turret),
		] + sides(3.2) {
			armour(length: 1.5, width: 3.8, z: 3.5 ... 7.8, x: 1, y: $0,
				front: 0.6, side: 0.3, corner: 0.4, tone: Tone.body)
		} + sides(4.8) {
			box(length: 2.5, width: 2.5, z: 0 ... 1.2, x: -12, y: $0, tone: Tone.turret)
		}) + cannon(from: at(2, 0, 6.8), to: at(18, 0, 17.8), caliber: 1.4, muzzle: true)
	}

	/// Tracked anti-air: faceted radar head, two raised autocannons and exposed road wheels.
	static var spaa: Model {
		tracked(length: 23, width: 13, count: 6)
		+ Model([
			armour(length: 22, width: 11.5, z: 3.8 ... 6.2,
				front: 4, rear: 0.5, side: 0.5, corner: 0.8, tone: Tone.body),
			cylinder(at: at(-5, 0, 11.5), radius: 0.7, length: 3, axis: .z, tone: Tone.barrel),
			armour(length: 1.8, width: 7.5, z: 11.3 ... 14.8, x: -5,
				front: 0.3, side: 0.5, corner: 0.5, tone: Tone.cargo),
		], lines: grille(x: -7, y: 2, z: 6.25, length: 3, width: 3) + [
			Line(from: at(-4.05, -2.6, 12.1), to: at(-4.05, 2.6, 12.1), tone: 125),
			Line(from: at(-4.05, -2.6, 13.5), to: at(-4.05, 2.6, 13.5), tone: 125),
		]) + turret(length: 9, width: 9, z: 6.4 ... 10.2, x: -1.5, front: 1.3, corner: 1.5)
		+ Model(sides(3.1) {
			barrel(from: at(1, $0, 8.8), to: at(14, $0, 12.5), caliber: 1.2, tone: Tone.barrel)
		})
	}

	/// Bofors: circular turntable, split shields, raised breech, sight and folding wheels.
	static var flak: Model {
		Model([
			box(length: 21, width: 2, z: 0.8 ... 2, x: -1.5, tone: Tone.running),
			box(length: 2.5, width: 19, z: 0.8 ... 2, tone: Tone.running),
			cylinder(at: at(0, 0, 2.5), radius: 3.4, length: 1.5, axis: .z, tone: Tone.turret),
			armour(length: 5, width: 5, z: 3 ... 6.5, front: 0.7, corner: 0.8, tone: Tone.turret),
			barrel(from: at(-2, 0, 7), to: at(9, 0, 23), caliber: 1.5, tone: Tone.barrel),
			barrel(from: at(-2, 0, 7), to: at(1.5, 0, 12.1), caliber: 2.8, tone: Tone.turret),
			box(length: 3, width: 2.5, z: 4.3 ... 5, x: -4.5, y: 3.5, tone: Tone.turret),
		] + sides(3.5) {
			armour(length: 2.3, width: 3.8, z: 5 ... 10.5, x: 1, y: $0,
				front: 0.8, side: 0.4, corner: 0.5, tone: Tone.body)
		} + sides(6) {
			cylinder(at: at(-5.5, $0, 2), radius: 2, length: 1.3, axis: .y, tone: 44)
		} + sides(6.7) {
			cylinder(at: at(-5.5, $0, 2), radius: 1, length: 0.3, axis: .y, tone: 125)
		} + sides(9) {
			box(length: 3, width: 3, z: 0 ... 1.2, y: $0, tone: Tone.turret)
		} + [-12, 9].map {
			box(length: 3, width: 3, z: 0 ... 1.2, x: $0, tone: Tone.turret)
		}, lines: [
			Line(from: at(-2, -2.5, 7), to: at(2, -2.5, 12), tone: Tone.antenna),
			Line(from: at(1, -3.5, 11.2), to: at(3, -1.5, 11.2), tone: Tone.antenna),
			Line(from: at(2, -2.5, 10.2), to: at(2, -2.5, 12.2), tone: Tone.antenna),
			Line(from: at(1.5, 0, 12.6), to: at(8.7, 0, 23.1), tone: Tone.barrel),
		])
	}
}

private extension Units {

	static func wheeled(at positions: [Float], width: Float, radius: Float) -> Model {
		var solids: [Solid] = []
		for x in positions {
			solids.append(box(length: 1, width: width, z: radius - 0.3 ... radius + 0.3, x: x, tone: Tone.running))
			for sign: Float in [-1, 1] {
				let y = sign * (width / 2 + 0.1)
				solids += [
					cylinder(at: at(x, y, radius), radius: radius, length: 1.4, axis: .y, tone: 42),
					cylinder(at: at(x, y + sign * 0.75, radius), radius: radius * 0.6, length: 0.2, axis: .y, tone: 110),
					cylinder(at: at(x, y + sign * 0.9, radius), radius: radius * 0.25, length: 0.2, axis: .y, tone: Tone.barrel),
				]
			}
		}
		return Model(solids)
	}

	static func tracked(length: Float, width: Float, count: Int) -> Model {
		var solids = sides((width - 2.6) / 2) { y in
			var track = box(length: length, width: 2.6, z: 0 ... 4.8, y: y, tone: 36)
			for sign: Float in [-1, 1] {
				track.planes += [
					Plane(normal: V3(sign, 0, -1), through: at(sign * length / 2, y, 1.2)),
					Plane(normal: V3(sign, 0, 1), through: at(sign * length / 2, y, 3.6)),
				]
			}
			return track
		}
		for sign: Float in [-1, 1] {
			for index in 0 ..< count {
				let x = (Float(index) / Float(count - 1) - 0.5) * (length - 4)
				let y = sign * width / 2
				solids += [
					cylinder(at: at(x, y, 2.4), radius: 1.65, length: 0.6, axis: .y, tone: 44),
					cylinder(at: at(x, y + sign * 0.35, 2.4), radius: 1.2, length: 0.2, axis: .y, tone: 110),
					cylinder(at: at(x, y + sign * 0.5, 2.4), radius: 0.5, length: 0.2, axis: .y, tone: Tone.barrel),
				]
			}
			solids.append(armour(length: length - 1, width: 2.8, z: 4.8 ... 5.3,
				y: sign * (width - 2.6) / 2, front: 0.5, rear: 0.5, corner: 0.4, tone: Tone.body))
		}
		return Model(solids)
	}

	static var truckChassis: Model {
		wheeled(at: [-9, -3, 8], width: 10, radius: 2.2) + Model([
			box(length: 26, width: 8, z: 2.4 ... 4.4, tone: Tone.running),
			box(length: 5, width: 1.5, z: 3 ... 4.5, x: 1.5, y: 4.5, tone: Tone.turret),
		])
	}

	static var truckCab: Model {
		Model([
			armour(length: 8.5, width: 10, z: 4 ... 10.5, x: 8,
				front: 0.8, rear: 0.3, side: 0.4, corner: 0.5, tone: Tone.body),
			box(length: 0.3, width: 7.4, z: 7.7 ... 9.5, x: 11.9, tone: 110),
			box(length: 0.4, width: 4.5, z: 5 ... 6.7, x: 12.2, tone: Tone.running),
			box(length: 1.2, width: 10.7, z: 3.6 ... 4.3, x: 12, tone: Tone.turret),
		] + sides(4.8) {
			box(length: 3.5, width: 0.2, z: 7.3 ... 9.5, x: 8, y: $0, tone: Tone.glass)
		} + sides(3.6) {
			box(length: 0.5, width: 1, z: 5.6 ... 6.5, x: 12.2, y: $0, tone: 220)
		}, lines: [
			Line(from: at(12.05, 0, 7.7), to: at(11.95, 0, 9.5), tone: Tone.body),
		] + sides(4.9) {
			Line(from: at(5.5, $0, 4.8), to: at(5.5, $0, 8), tone: 115)
		})
	}

	static func cannon(from start: V3, to end: V3, caliber: Float, muzzle: Bool = false) -> Model {
		let axis = (end - start).normalized
		var solids = [
			barrel(from: start, to: end, caliber: caliber, tone: Tone.barrel),
			barrel(from: start, to: start + axis * 3, caliber: caliber * 1.5, tone: Tone.turret),
		]
		if muzzle {
			solids.append(barrel(from: end - axis * 1.8, to: end, caliber: caliber * 1.6, tone: Tone.turret))
		}
		return Model(solids, lines: [
			Line(from: start + axis * 3 + V3(0, 0, caliber / 2),
				to: end - axis * 0.7 + V3(0, 0, caliber / 2), tone: Tone.barrel),
		])
	}
}
