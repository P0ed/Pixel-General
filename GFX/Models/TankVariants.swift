public extension Units {

	/// T-55: five large road wheels, a round cast turret and a muzzle-end bore evacuator.
	static var t55: Model {
		tankChassis(length: 34.5, width: 20.25, wheels: 5, deck: 8.55)
		+ Model([
			armour(length: 33, width: 18, z: 5.7 ... 8.55, front: 6, rear: 1.2,
				side: 0.75, corner: 1.5, tone: Tone.body),
			cylinder(at: at(-1.05, 0, 10.2), radius: 7.5, length: 3.3, axis: .z, tone: Tone.turret),
			cylinder(at: at(-1.5, 0, 12.3), radius: 5.7, length: 1.65, axis: .z, tone: Tone.turret),
			cylinder(at: at(25.2, 0, 11.1), radius: 1.65, length: 4.2, axis: .x, tone: Tone.turret),
			cylinder(at: at(3.75, -4.5, 13.2), radius: 1.8, length: 1.8, axis: .x, tone: Tone.glass),
		] + sides(6) { cylinder(at: at(-12.75, $0, 9.3), radius: 1.5, length: 6, axis: .x, tone: Tone.cargo) })
		+ tankGun(from: 5.25, length: 23.25, z: 11.1, caliber: 1.8)
		+ tankRoof(x: -3.3, z: 13.05)
	}

	/// M48 Patton: six wheels, a rounded bow, cast turret and tall commander's cupola.
	static var m48: Model {
		tankChassis(length: 36, width: 21.75, wheels: 6, deck: 9.9)
		+ Model([
			armour(length: 34.5, width: 19.5, z: 5.7 ... 9.9, front: 5.25, rear: 2.7,
				side: 1.5, corner: 3.6, tone: Tone.body),
			cylinder(at: at(-2.25, 0, 12), radius: 7.95, length: 4.2, axis: .z, tone: Tone.turret),
			armour(length: 12, width: 12, z: 13.5 ... 16.2, x: -3, front: 1.95, rear: 1.8,
				side: 1.8, corner: 2.25, tone: Tone.turret),
			cylinder(at: at(-3.45, 3, 17.4), radius: 2.7, length: 3.6, axis: .z, tone: Tone.turret),
			barrel(from: at(-1.5, 3, 18), to: at(6, 3, 18.45), caliber: 1.05, tone: Tone.barrel),
			box(length: 3, width: 3, z: 14.55 ... 16.5, x: 3, y: -2.7, tone: Tone.glass),
		]) + tankGun(from: 5.7, length: 21.75, z: 13.05, caliber: 1.95)
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
		}) + tankGun(from: 4.5, length: 24, z: 7.95, caliber: 1.95)
	}

	/// KF51: angular autoloader bustle, a larger gun and roof-mounted drone canisters.
	static var kf51: Model {
		tankChassis(length: 39, width: 22.5, wheels: 7, deck: 9.6)
		+ Model([
			armour(length: 37.5, width: 20.25, z: 6 ... 9.6, front: 7.5, rear: 1.5,
				side: 0.9, corner: 1.8, tone: Tone.body),
			armour(length: 7.5, width: 12, z: 12.3 ... 17.7, x: -12, rear: 1.5,
				side: 0.6, corner: 1.5, tone: Tone.turret),
			box(length: 6, width: 3.9, z: 17.4 ... 19.05, x: -7.95, y: -3.3, tone: Tone.cargo),
			box(length: 3, width: 3, z: 17.4 ... 20.25, x: -0.75, y: 3.45, tone: Tone.glass),
		])
		+ tankTurret(length: 21, width: 16.5, z: 9.9 ... 17.4, x: -2.25,
			front: 5.1, rear: 1.5, side: 1.8, corner: 3)
		+ tankSkirts(length: 34.5, width: 22.5, z: 3.9 ... 8.7)
		+ tankGun(from: 7.5, length: 24.75, z: 13.5, caliber: 2.85)
		+ tankRoof(x: -4.5, z: 17.4)
	}
}
