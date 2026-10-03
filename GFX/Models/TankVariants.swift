public extension Units {

	/// T-55: five large road wheels, a round cast turret and a muzzle-end bore evacuator.
	static var t55: Model {
		tankChassis(length: 23, width: 13.5, wheels: 5, deck: 5.7)
		+ Model([
			armour(length: 22, width: 12, z: 3.8 ... 5.7, front: 4, rear: 0.8,
				side: 0.5, corner: 1, tone: Tone.body),
			cylinder(at: at(-0.7, 0, 6.8), radius: 5, length: 2.2, axis: .z, tone: Tone.turret),
			cylinder(at: at(-1, 0, 8.2), radius: 3.8, length: 1.1, axis: .z, tone: Tone.turret),
			cylinder(at: at(16.8, 0, 7.4), radius: 1.1, length: 2.8, axis: .x, tone: Tone.turret),
			cylinder(at: at(2.5, -3, 8.8), radius: 1.2, length: 1.2, axis: .x, tone: Tone.glass),
		] + sides(4) { cylinder(at: at(-8.5, $0, 6.2), radius: 1, length: 4, axis: .x, tone: Tone.cargo) })
		+ tankGun(from: 3.5, length: 15.5, z: 7.4, caliber: 1.2)
		+ tankRoof(x: -2.2, z: 8.7)
	}

	/// M48 Patton: six wheels, a rounded bow, cast turret and tall commander's cupola.
	static var m48: Model {
		tankChassis(length: 24, width: 14.5, wheels: 6, deck: 6.6)
		+ Model([
			armour(length: 23, width: 13, z: 3.8 ... 6.6, front: 3.5, rear: 1.8,
				side: 1, corner: 2.4, tone: Tone.body),
			cylinder(at: at(-1.5, 0, 8), radius: 5.3, length: 2.8, axis: .z, tone: Tone.turret),
			armour(length: 8, width: 8, z: 9 ... 10.8, x: -2, front: 1.3, rear: 1.2,
				side: 1.2, corner: 1.5, tone: Tone.turret),
			cylinder(at: at(-2.3, 2, 11.6), radius: 1.8, length: 2.4, axis: .z, tone: Tone.turret),
			barrel(from: at(-1, 2, 12), to: at(4, 2, 12.3), caliber: 0.7, tone: Tone.barrel),
			box(length: 2, width: 2, z: 9.7 ... 11, x: 2, y: -1.8, tone: Tone.glass),
		]) + tankGun(from: 3.8, length: 14.5, z: 8.7, caliber: 1.3)
	}

	/// Strv 103: no turret; the fixed gun emerges from the sharply sloped hull.
	static var strv103: Model {
		tankChassis(length: 24, width: 14, wheels: 4, deck: 5.4)
		+ Model([
			armour(length: 23, width: 13, z: 3.4 ... 7.6, front: 9, rear: 2,
				side: 0.7, corner: 1, tone: Tone.body),
			box(length: 1, width: 13.5, z: 0.6 ... 3, x: 11, tone: Tone.turret),
			hatch(x: -4.5, y: 2.3, z: 7.6, radius: 1.6),
			hatch(x: -4.5, y: -2.3, z: 7.6),
			cylinder(at: at(-5, 2.3, 8.4), radius: 1.3, length: 1.1, axis: .z, tone: Tone.turret),
		], lines: grille(x: -8.3, z: 7.65, length: 3.5, width: 7) + sides(6.4) { y in
			Line(from: at(-9, y, 5.6), to: at(7, y, 5.6), tone: 100, dash: 1.5)
		}) + tankGun(from: 3, length: 16, z: 5.3, caliber: 1.3)
	}

	/// KF51: angular autoloader bustle, a larger gun and roof-mounted drone canisters.
	static var kf51: Model {
		tankChassis(length: 26, width: 15, wheels: 7, deck: 6.4)
		+ Model([
			armour(length: 25, width: 13.5, z: 4 ... 6.4, front: 5, rear: 1,
				side: 0.6, corner: 1.2, tone: Tone.body),
			armour(length: 5, width: 8, z: 8.2 ... 11.8, x: -8, rear: 1,
				side: 0.4, corner: 1, tone: Tone.turret),
			box(length: 4, width: 2.6, z: 11.6 ... 12.7, x: -5.3, y: -2.2, tone: Tone.cargo),
			box(length: 2, width: 2, z: 11.6 ... 13.5, x: -0.5, y: 2.3, tone: Tone.glass),
		])
		+ tankTurret(length: 14, width: 11, z: 6.6 ... 11.6, x: -1.5,
			front: 3.4, rear: 1, side: 1.2, corner: 2)
		+ tankSkirts(length: 23, width: 15, z: 2.6 ... 5.8)
		+ tankGun(from: 5, length: 16.5, z: 9, caliber: 1.9)
		+ tankRoof(x: -3, z: 11.6)
	}
}
