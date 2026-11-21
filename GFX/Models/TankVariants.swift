public extension Units {

	/// T-55: a low cast dome, five large road wheels and twin rear fuel drums.
	static var t55: Model {
		tankChassis(length: 34.5, width: 20.25, wheels: 5, deck: 8.55)
		+ Model([
			armour(length: 34.2, width: 16.8, z: 5.7 ... 8.55, front: 7.2, rear: 0.9,
				side: 0.45, corner: 1.2, tone: Tone.body),
			castTurret(length: 16.2, width: 16.5, z: 8.55 ... 13.5, x: -1.2),
			hatch(x: -3.3, y: 2.55, z: 13.5, radius: 2.25),
			hatch(x: -3.9, y: -2.55, z: 13.5, radius: 1.65),
			cylinder(at: at(4.2, -2.85, 13.05), radius: 1.65, length: 1.95, axis: .x, tone: Tone.cargo),
			cylinder(at: at(5.25, -2.85, 13.05), radius: 1.35, length: 0.45, axis: .x, tone: 108),
			cylinder(at: at(25.2, 0, 11.85), radius: 1.5, length: 4.65, axis: .x, tone: Tone.turret),
		] + sides(4.65) {
			cylinder(at: at(-16.2, $0, 8.4), radius: 1.5, length: 6.6, axis: .y, tone: Tone.cargo)
		}, lines: [
			Line(from: at(-6.6, 2.1, 12.9), to: at(-7.65, 2.1, 18.9), tone: Tone.antenna),
		])
		+ tankGun(from: 5.1, length: 23.4, z: 11.85, caliber: 1.8)
	}

	/// M48 Patton: six wheels, a rounded bow, cast turret and tall commander's cupola.
	static var m48: Model {
		let deck: Float = 10.35
		var bow = armour(length: 35.4, width: 19.5, z: 5.1 ... deck, front: 3.45, rear: 1.5,
			side: 0.75, corner: 6, tone: Tone.body)
		bow.planes.append(Plane(normal: V3(1, 0, -1.2), through: at(13.8, 0, 5.1)))

		return tankChassis(length: 36, width: 21.75, wheels: 6, deck: deck)
		+ Model([
			bow,
			castTurret(length: 19.2, width: 17.7, z: 10.2 ... 17.25, x: -2.55),
			armour(length: 3.75, width: 7.2, z: 11.85 ... 16.35, x: 4.65,
				front: 1.05, side: 0.45, corner: 1.2, tone: Tone.cargo),
			cylinder(at: at(-1.65, 3.45, 18), radius: 2.7, length: 3, axis: .z, tone: Tone.turret),
			hatch(x: -4.35, y: -2.55, z: 17.25, radius: 2.1),
			barrel(from: at(-0.45, 3.45, 18.9), to: at(4.95, 3.45, 19.2), caliber: 1.05, tone: Tone.barrel),
			cylinder(at: at(24.15, 0, 14.1), radius: 1.35, length: 3.6, axis: .x, tone: Tone.turret),
			cylinder(at: at(28.2, 0, 14.1), radius: 1.2, length: 3.6, axis: .y, tone: Tone.turret),
		] + sides(8.7) {
			var fender = cylinder(at: at(15.15, $0, 8.1), radius: 2.55, length: 4.35, axis: .y, tone: Tone.body)
			fender.planes.append(Plane(normal: V3(0, 0, -1), offset: -8.1))
			return fender
		} + sides(4.8) {
			cylinder(at: at(13.65, $0, 10.05), radius: 0.9, length: 1.35, axis: .x, tone: 235)
		})
		+ tankGun(from: 5.7, length: 22.8, z: 14.1, caliber: 1.8)
	}

	/// Strv 103: no turret; the fixed gun emerges from the sharply sloped hull.
	static var strv103: Model {
		tankChassis(length: 36, width: 21, wheels: 4, deck: 8.1)
		+ Model([
			armour(length: 34.5, width: 19.5, z: 5.1 ... 11.4, front: 13.5, rear: 3,
				side: 1.05, corner: 1.5, tone: Tone.body),
			box(length: 1.5, width: 20.25, z: 0.9 ... 4.5, x: 16.5, tone: Tone.turret),
			hatch(x: -6.75, y: 3.45, z: 11.4, radius: 2.4),
			hatch(x: -6.75, y: -3.45, z: 11.4),
			cylinder(at: at(-7.5, 3.45, 12.6), radius: 1.95, length: 1.65, axis: .z, tone: Tone.turret),
		], lines: grille(x: -12.45, z: 11.475, length: 5.25, width: 10.5) + sides(9.6) { y in
			Line(from: at(-13.5, y, 8.4), to: at(10.5, y, 8.4), tone: 100, dash: 2.25)
		}) + tankGun(from: 4.5, length: 24, z: 10.2, caliber: 1.95)
	}

	/// KF51 Panther demonstrator: wide turret cheeks, a deep rear bustle and a tall roof sight.
	static var kf51: Model {
		tankChassis(length: 39, width: 22.5, wheels: 7, deck: 9.6)
		+ Model([
			armour(length: 38.4, width: 20.7, z: 6 ... 9.6, front: 6.75, rear: 1.5,
				side: 0.6, corner: 2.1, tone: Tone.body),
			armour(length: 22.8, width: 17.4, z: 10.35 ... 16.8, x: -3.6,
				front: 2.7, rear: 0.9, side: 1.2, corner: 2.1, tone: Tone.turret),
			armour(length: 7.5, width: 15.75, z: 12.15 ... 17.55, x: -11.85,
				front: 0.45, rear: 1.05, side: 0.75, corner: 2.1, tone: Tone.turret),
			armour(length: 3.75, width: 4.05, z: 11.7 ... 15, x: 6.3,
				front: 1.05, side: 0.45, corner: 0.75, tone: Tone.cargo),
			box(length: 2.7, width: 3.3, z: 16.65 ... 20.1, x: 0.45, y: 3.75, tone: Tone.turret),
			box(length: 0.6, width: 2.1, z: 17.85 ... 19.65, x: 1.95, y: 3.75, tone: 94),
			armour(length: 5.25, width: 4.2, z: 16.65 ... 18.15, x: -4.05, y: -3.6,
				front: 0.9, side: 0.45, corner: 0.75, tone: Tone.cargo),
		] + sides(5.55) {
			armour(length: 7.8, width: 6.45, z: 11.4 ... 16.8, x: 5.1, y: $0,
				front: 4.2, rear: 0.45, side: 0.45, corner: 1.2, tone: Tone.body)
		}, lines: sides(5.7) {
			Line(from: at(-11.7, $0, 17.55), to: at(-12.6, $0, 23.4), tone: Tone.antenna)
		} + sides(8.85) {
			Line(from: at(17.1, $0 - 0.9, 8.25), to: at(17.1, $0 + 0.9, 8.25), tone: 176)
		})
		+ tankSkirts(length: 36, width: 22.5, z: 4.5 ... 8.7)
		+ tankGun(from: 7.5, length: 24.75, z: 13.65, caliber: 2.85)
	}
}

private extension Units {

	/// Twelve facets around three slopes give the cast turret a rounded shoulder and crown.
	static func castTurret(length: Float, width: Float, z: ClosedRange<Float>, x: Float) -> Solid {
		var turret = box(length: length, width: width, z: z, x: x, tone: Tone.turret)
		let center = at(x, 0, z.lowerBound)
		let height = z.upperBound - z.lowerBound
		let directions: [(Float, Float)] = [
			(1, 0), (0.866, 0.5), (0.5, 0.866), (0, 1), (-0.5, 0.866), (-0.866, 0.5),
			(-1, 0), (-0.866, -0.5), (-0.5, -0.866), (0, -1), (0.5, -0.866), (0.866, -0.5),
		]
		let slopes: [(Float, Float)] = [(-0.36, 0.87), (0.24, 1.06), (0.94, 1.53)]
		for (dx, dy) in directions {
			let side = V3(2 * dx / length, 2 * dy / width, 0)
			turret.planes += slopes.map { tilt, radius in
				let normal = side + V3(0, 0, tilt / height)
				return Plane(normal: normal, offset: normal.dot(center) + radius)
			}
		}
		return turret
	}
}
