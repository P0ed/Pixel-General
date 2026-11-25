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

	/// Fennek scout car: a low wedge nose, wraparound glazing and a raised observation mast.
	static var fennek: Model {
		let roof: Float = 14.1
		let glazing: ClosedRange<Float> = 10.5 ... 13.65
		let windowRake: Float = 3.825
		let windowTone: UInt8 = 90
		let mastX: Float = -4.5
		let mastY: Float = -2.25
		var shoulders = armour(length: 33.6, width: 16.5, z: 7.95 ... 10.5,
			front: 0.75, rear: 0.45, side: 0.45, corner: 1.8, tone: Tone.body)
		shoulders.planes += [
			Plane(normal: V3(0.18, 0, 1), through: at(9, 0, 10.5)),
			Plane(normal: V3(1, 0, -1.2), through: at(15, 0, 7.95)),
			Plane(normal: V3(-1, 0, -0.75), through: at(-15.3, 0, 7.95)),
		]

		// The skirt flares above the tyres to form the inner edges of both wheel arches.
		var skirt = box(length: 18.6, width: 16.5, z: 4.35 ... 8.1, tone: Tone.body)
		skirt.planes += [
			Plane(normal: V3(1, 0, -0.8), through: at(6.3, 0, 4.35)),
			Plane(normal: V3(-1, 0, -0.8), through: at(-6.3, 0, 4.35)),
			Plane(normal: V3(0, 1, -0.15), through: at(0, 8.25, 7.95)),
			Plane(normal: V3(0, -1, -0.15), through: at(0, -8.25, 7.95)),
		]

		return wheeled(at: [-10.65, 10.65], width: 15.75, radius: 4.05)
		+ Model([
			box(length: 31.2, width: 10.5, z: 4.95 ... 8.25, tone: Tone.turret),
			skirt,
			shoulders,
			armour(length: 26.4, width: 16.5, z: 9.9 ... roof, x: -2.85,
				front: 5.1, rear: 0.9, side: 1.35, corner: 0.9, tone: Tone.body),
			armour(length: 7.2, width: 13.5, z: glazing, x: 6.3,
				front: windowRake, side: 1.05, corner: 0.3, tone: windowTone),
			hatch(x: 1.95, y: 2.55, z: roof, radius: 2.4),
			box(length: 3.9, width: 3.9, z: roof ... 15.45, x: mastX, y: mastY, tone: Tone.turret),
			box(length: 1.35, width: 1.65, z: 15.45 ... 20.55, x: mastX, y: mastY, tone: Tone.barrel),
			armour(length: 3.3, width: 4.5, z: 20.55 ... 23.85, x: mastX, y: mastY,
				corner: 0.6, tone: Tone.turret),
			cylinder(at: at(mastX + 1.8, mastY, 22.35), radius: 1.2, length: 0.6, axis: .x, tone: 78),
		] + sides(7.05) {
			armour(length: 8.1, width: 2.7, z: glazing, x: 4.05, y: $0,
				front: windowRake, side: 1.05, tone: windowTone)
		} + sides(5.4) {
			box(length: 1.5, width: 1.8, z: 8.1 ... 9.45, x: 16.05, y: $0, tone: 235)
		}, lines: grille(x: -10.5, y: -1.5, z: roof + 0.075, length: 2.25, width: 3.6, tone: 120) + [
			Line(from: at(-13.2, 4.95, roof), to: at(-15, 4.95, 23.4), tone: Tone.antenna),
		])
	}

	/// BRDM-2: an upturned amphibious bow, paired windshields and a low conical turret.
	static var brdm2: Model {
		let roof: Float = 14.4
		var hull = armour(length: 34.5, width: 16.5, z: 4.2 ... 9.9,
			corner: 3, tone: Tone.body)
		hull.planes += [
			Plane(normal: V3(1, 0, -1.65), through: at(8.1, 0, 4.2)),
			Plane(normal: V3(-1, 0, -0.65), through: at(-14.1, 0, 4.2)),
			Plane(normal: V3(0, 1, -0.3), through: at(0, 8.25, 9.9)),
			Plane(normal: V3(0, -1, -0.3), through: at(0, -8.25, 9.9)),
		]
		let bellyWheels = wheeled(at: [-2.7, 2.7], width: 10.5, radius: 1.8).translated(by: V3(0, 0, 2.4))

		return wheeled(at: [-10.8, 10.8], width: 15.9, radius: 3.9) + bellyWheels
		+ Model([
			hull,
			armour(length: 25.8, width: 16.2, z: 9.75 ... roof, x: -3.75,
				front: 4.2, rear: 1.8, side: 1.95, corner: 1.05, tone: Tone.body),
			hatch(x: -12, y: -3, z: roof),
			cylinder(at: at(-2.55, 0, 14.7), radius: 3.75, length: 0.9, axis: .z, tone: Tone.turret),
			armour(length: 7.2, width: 7.8, z: 14.85 ... 18, x: -2.55,
				front: 1.65, rear: 1.35, side: 1.8, corner: 2.4, tone: Tone.turret),
			barrel(from: at(-0.3, 0, 16.35), to: at(9.6, 0, 18.15), caliber: 1.35, tone: Tone.barrel),
		] + sides(2.55) {
			armour(length: 4.5, width: 4.2, z: 11.4 ... 13.8, x: 5.7, y: $0,
				front: 2.175, side: 0.15, tone: 96)
		} + sides(5.7) {
			cylinder(at: at(11.55, $0, 10.65), radius: 1.05, length: 1.35, axis: .x, tone: 235)
		}, lines: grille(x: -10.8, y: 2.25, z: roof + 0.075, length: 2.25, width: 4.5, tone: 115) + [
			Line(from: at(15.75, -6.15, 9.95), to: at(15.75, 6.15, 9.95), tone: 110),
			Line(from: at(-11.7, -5.1, roof), to: at(-13.2, -5.1, 20.7), tone: Tone.antenna),
		])
	}

	/// Boxer CRV: a long glacis, tall rear mission module and broad Lance turret.
	static var boxer: Model {
		let roof: Float = 15.3
		var bow = armour(length: 12.3, width: 17.7, z: 5.7 ... 8.25, x: 13.65,
			corner: 2.4, tone: Tone.turret)
		bow.planes.append(Plane(normal: V3(1, 0, -1.35), through: at(16.35, 0, 5.7)))
		let fenders = [-10.2, -0.9, 8.4].map { (x: Float) in
			var fender = box(length: 5.4, width: 19.2, z: 5.7 ... 8.25, x: x, tone: Tone.turret)
			fender.planes += [
				Plane(normal: V3(1, 0, -0.9), through: at(x + 0.75, 0, 5.7)),
				Plane(normal: V3(-1, 0, -0.9), through: at(x - 0.75, 0, 5.7)),
			]
			return fender
		}

		return wheeled(at: [-14.1, -6.3, 4.5, 12.3], width: 18.3, radius: 3.825)
		+ Model([
			bow,
			armour(length: 39.6, width: 19.5, z: 7.5 ... 13.8,
				front: 12.6, rear: 1.2, side: 0.6, corner: 2.4, tone: Tone.body),
			armour(length: 21.6, width: 19.2, z: 11.4 ... roof, x: -8.1,
				front: 0.9, rear: 0.75, side: 0.75, corner: 1.35, tone: Tone.body),
			armour(length: 4.5, width: 4.5, z: 11.4 ... 14.25, x: 9.3, y: 4.2,
				front: 1.5, side: 0.45, corner: 0.45, tone: Tone.turret),
			box(length: 1.2, width: 3, z: 13.05 ... 13.8, x: 10.65, y: 4.2, tone: 90),
			hatch(x: -15, y: 4.05, z: roof, radius: 2.1),
		] + fenders + sides(6.15) {
			armour(length: 2.7, width: 1.8, z: 7.95 ... 9.15, x: 17.7, y: $0,
				front: 2.4, tone: 235)
		}, lines: sides(9.45) {
			Line(from: at(-17.4, $0, 12.45), to: at(1.65, $0, 12.45), tone: 104)
		} + [
			Line(from: at(-16.5, -6.9, roof), to: at(-18, -6.9, 22.2), tone: Tone.antenna),
			Line(from: at(-16.5, 6.9, roof), to: at(-17.7, 6.9, 21), tone: Tone.antenna),
		])
		+ turret(length: 12.6, width: 13.2, z: 15.3 ... 20.1, x: -3,
			front: 2.1, rear: 1.2, side: 1.65, corner: 2.55)
		+ Model([
			armour(length: 4.5, width: 3, z: 16.35 ... 19.8, x: -1.5, y: 5.1,
				front: 0.75, side: 0.45, corner: 0.6, tone: Tone.turret),
			box(length: 2.55, width: 2.85, z: 20.1 ... 22.35, x: -4.05, y: -2.85, tone: Tone.turret),
			box(length: 0.6, width: 1.65, z: 20.85 ... 21.9, x: -2.7, y: -2.85, tone: 93),
		])
		+ cannon(from: at(1.5, 0, 17.7), to: at(17.25, 0, 18.45), caliber: 1.8)
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

	static var pzh2000: Model {
		let deck: Float = 10.35
		let roof: Float = 20.4
		var bow = box(length: 38.1, width: 14.1, z: 3.6 ... 7.65, tone: Tone.turret)
		bow.planes.append(Plane(normal: V3(1, 0, -1.05), through: at(19.05, 0, 7.65)))
		var turret = armour(length: 23.7, width: 19.2, z: 10.8 ... roof, x: -5.1,
			front: 3.3, rear: 0.9, side: 1.2, corner: 1.5, tone: Tone.turret)
		turret.planes += sides(1) { side in
			Plane(normal: V3(0, side, 0.86), through: at(0, side * 8.8, 16.95))
		}

		let skirts = sides(10.8) { y in
			let panelCenters: [Float] = [-14.4, -5.4, 3.6, 12.6]
			return panelCenters.map { x in
				var panel = box(length: 9, width: 0.9, z: 5.85 ... 8.7, x: x, y: y, tone: Tone.turret)
				panel.planes += sides(1) { side in
					Plane(normal: V3(side, 0, -1), through: at(x + side * 4.5, y, 7.35))
				}
				return panel
			}
		}.flatMap { $0 }
		let lamps = sides(8.25) { y in
			[
				box(length: 2.1, width: 2.7, z: 7.95 ... 9.45, x: 15.45, y: y, tone: Tone.body),
				cylinder(at: at(16.5, y, 9.15), radius: 0.93, length: 0.9, axis: .x, tone: 245),
			]
		}.flatMap { $0 }

		let gunBase = at(5.4, 0, 17.1)
		let muzzle = at(33, 0, 28.5)
		let gunAxis = (muzzle - gunBase).normalized
		let brakeStart = muzzle - gunAxis * 3.6
		let ventSlats: [Float] = [13.5, 14.85, 16.2]

		return tracked(length: 39, width: 21, count: 7)
		+ Model([
			bow,
			armour(length: 38.4, width: 21, z: 7.65 ... deck,
				front: 6.75, rear: 0.75, side: 0.45, corner: 0.75, tone: Tone.body),
			box(length: 1.35, width: 21, z: 6.6 ... 8.25, x: 18.825, tone: Tone.body),
			hatch(x: 9.9, y: 3.3, z: deck, radius: 2.1),
			cylinder(at: at(-4.5, 0, 10.575), radius: 7.5, length: 0.45, axis: .z, tone: Tone.running),
		] + skirts + lamps, lines: grille(x: 9.15, y: -3.9, z: deck + 0.075, length: 5.1, width: 5.7))
		+ Model([
			turret,
			armour(length: 4.5, width: 5.7, z: 13.35 ... 19.05, x: 4.95,
				front: 1.05, side: 0.45, corner: 0.6, tone: Tone.cargo),
			armour(length: 2.55, width: 3.75, z: 12.75 ... 17.55, x: 5.25, y: 4.65,
				front: 1.8, side: 0.3, corner: 0.3, tone: 88),
			hatch(x: -5.4, y: 3, z: roof, radius: 2.1),
			hatch(x: -9.75, y: -2.7, z: roof, radius: 1.8),
			box(length: 2.4, width: 3.3, z: 19.8 ... 22.05, x: 3.3, y: -1.65, tone: Tone.turret),
			box(length: 0.45, width: 2.4, z: 20.55 ... 21.6, x: 4.575, y: -1.65, tone: Tone.glass),
		], lines: ventSlats.map { z in
			let x = 6.525 - (z - 12.75) * 0.375
			return Line(from: at(x, 3.3, z), to: at(x, 6, z), tone: 92)
		} + [
			Line(from: at(-12.9, -4.2, roof), to: at(-14.1, -4.2, 26.4), tone: Tone.antenna),
			Line(from: at(-11.4, 4.2, roof), to: at(-12.15, 4.2, 25.5), tone: Tone.antenna),
		])
		+ cannon(from: gunBase, to: brakeStart + gunAxis * 0.3, caliber: 2.25)
		+ Model(
			barrel(from: brakeStart, to: muzzle, caliber: 3.3, tone: 115),
			barrel(from: muzzle - gunAxis * 0.4, to: muzzle + gunAxis * 0.025, caliber: 1.8, tone: 45)
		)
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
