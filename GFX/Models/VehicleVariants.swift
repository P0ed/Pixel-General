public extension Units {

	static var m1117: Model {
		wheeled(at: [-9.75, 9.75], width: 15.75, radius: 3.6)
		+ Model([
			armour(length: 31.5, width: 15.75, z: 5.25 ... 12, front: 6.75, rear: 3.75,
				side: 1.5, corner: 1.95, tone: Tone.body),
			box(length: 1.05, width: 9, z: 9.75 ... 11.7, x: 9, tone: Tone.glass),
			hatch(x: -9.75, y: -3.75, z: 12),
		], lines: sides(7.5) { Line(from: at(-1.5, $0, 6.45), to: at(-1.5, $0, 11.25), tone: 100) })
		+ turret(length: 9, width: 9, z: 12.3 ... 16.5, x: -1.5, corner: 1.95)
		+ cannon(from: at(1.5, 0, 14.55), to: at(11.25, 0, 15), caliber: 1.95)
	}

	static var stryker: Model {
		wheeled(at: [-13.5, -4.95, 4.95, 13.5], width: 17.25, radius: 3.15)
		+ Model([
			armour(length: 37.5, width: 17.25, z: 5.7 ... 12, front: 7.5, rear: 0.9,
				side: 1.5, corner: 2.1, tone: Tone.body),
			hatch(x: -10.5, y: 3.75, z: 12, radius: 2.1),
			hatch(x: 6, y: -3.75, z: 12),
			box(length: 6, width: 3, z: 12 ... 12.9, x: -6.75, y: -4.5, tone: Tone.cargo),
		], lines: grille(x: -10.5, y: -3.75, z: 12.15, length: 5.25, width: 4.5))
		+ turret(length: 5.25, width: 5.25, z: 12.45 ... 16.5, x: 1.5, corner: 1.05)
		+ cannon(from: at(3, 0, 15), to: at(10.5, 0, 15.45), caliber: 1.35)
	}

	static var btr80: Model {
		wheeled(at: [-13.5, -4.8, 4.8, 13.5], width: 16.5, radius: 3.45)
		+ Model([
			armour(length: 39, width: 16.5, z: 5.25 ... 10.8, front: 9, rear: 3,
				side: 1.95, corner: 2.4, tone: Tone.body),
			hatch(x: -9, y: -3.75, z: 10.8), hatch(x: -9, y: 3.75, z: 10.8),
			box(length: 1.5, width: 9, z: 9.45 ... 10.8, x: 10.05, tone: Tone.glass),
		], lines: grille(x: -13.5, z: 10.95, length: 4.5, width: 7.5))
		+ turret(length: 6.75, width: 6.75, z: 11.1 ... 15, x: 1.95, side: 1.8, corner: 1.5)
		+ cannon(from: at(4.5, 0, 13.05), to: at(15, 0, 13.5), caliber: 1.5)
	}

	static var fv432: Model {
		tracked(length: 31.5, width: 18, count: 5)
		+ Model([
			armour(length: 30, width: 15.75, z: 5.7 ... 13.8, front: 3.75, rear: 0.45,
				side: 0.3, corner: 0.75, tone: Tone.body),
			hatch(x: -6, z: 13.8, radius: 3.3), hatch(x: 4.5, y: -3, z: 13.8),
			cylinder(at: at(-3, 4.2, 14.85), radius: 1.95, length: 1.5, axis: .z, tone: Tone.turret),
			barrel(from: at(-1.5, 4.2, 15.3), to: at(7.5, 4.2, 15.45), caliber: 1.05, tone: Tone.barrel),
			box(length: 12, width: 1.05, z: 9 ... 10.5, x: -1.5, y: -8.25, tone: Tone.cargo),
		], lines: grille(x: 4.5, y: 3, z: 13.95, length: 6, width: 4.5))
	}

	static var mtLb: Model {
		tracked(length: 34.5, width: 17.25, count: 6)
		+ Model([
			armour(length: 33, width: 15, z: 5.7 ... 10.05, front: 7.5, rear: 1.2,
				side: 0.6, corner: 1.2, tone: Tone.body),
			hatch(x: -10.5, y: -3, z: 10.05), hatch(x: -5.25, y: -3, z: 10.05),
			cylinder(at: at(6, 3.15, 11.1), radius: 2.25, length: 1.8, axis: .z, tone: Tone.turret),
			barrel(from: at(7.5, 3.15, 11.7), to: at(13.5, 3.15, 12), caliber: 1.05, tone: Tone.barrel),
		], lines: grille(x: -6, y: 3.15, z: 10.2, length: 7.5, width: 4.5))
	}

	static var m2A2: Model {
		ifvHull(length: 34.5, width: 19.5, deck: 12.45, front: 6.3)
		+ turret(length: 12.75, width: 11.25, z: 12.75 ... 18, x: -1.5, y: -1.2, front: 2.7, corner: 2.1)
		+ Model([
			hatch(x: -3, y: 1.2, z: 18),
			box(length: 7.5, width: 3.3, z: 14.25 ... 18, x: -1.5, y: 6.45, tone: Tone.cargo),
			box(length: 1.8, width: 3, z: 16.5 ... 19.2, x: 1.95, y: -3, tone: Tone.glass),
		]) + cannon(from: at(3.6, -1.2, 15.6), to: at(20.25, -1.2, 16.2), caliber: 1.8)
	}

	static var marder: Model {
		ifvHull(length: 36, width: 18.75, deck: 12.9, front: 8.25)
		+ turret(length: 9.75, width: 8.25, z: 13.2 ... 16.5, x: 0.75, front: 2.25, corner: 1.5)
		+ Model([
			hatch(x: -9, y: 2.25, z: 12.9, radius: 2.1),
			barrel(from: at(-1.5, 3.6, 17.55), to: at(6, 3.6, 18.15), caliber: 2.1, tone: Tone.cargo),
			armour(length: 5.25, width: 4.8, z: 13.05 ... 15.75, x: -10.5, corner: 0.9, tone: Tone.turret),
		]) + cannon(from: at(4.5, 0, 15), to: at(19.5, 0, 15.75), caliber: 1.5)
	}

	static var bmp2: Model {
		ifvHull(length: 36, width: 18, deck: 9.75, front: 9)
		+ turret(length: 9.75, width: 9.75, z: 10.05 ... 14.1, x: -3, side: 1.65, corner: 2.25)
		+ Model([
			hatch(x: -4.5, y: 1.95, z: 14.1),
			barrel(from: at(-3, 0, 15), to: at(4.5, 0, 15.45), caliber: 1.65, tone: Tone.running),
			box(length: 15, width: 0.9, z: 8.7 ... 10.05, x: -6.75, y: 8.55, tone: Tone.cargo),
		]) + cannon(from: at(0.75, 0, 12.3), to: at(21, 0, 13.2), caliber: 1.5)
	}

	static var cv9035: Model {
		ifvHull(length: 33, width: 18.75, deck: 11.25, front: 6.75)
		+ turret(length: 12.75, width: 11.7, z: 11.55 ... 16.8, x: -3, front: 3, corner: 2.55)
		+ Model([
			hatch(x: -4.5, y: 2.1, z: 16.8),
			box(length: 3, width: 3, z: 16.8 ... 18.9, x: -0.75, y: -3, tone: Tone.glass),
		]) + cannon(from: at(1.8, 0, 14.25), to: at(19.5, 0, 15), caliber: 2.1)
	}

	static var kf41: Model {
		ifvHull(length: 37.5, width: 20.25, deck: 13.5, front: 7.5)
		+ turret(length: 14.25, width: 12, z: 13.8 ... 18.3, x: -3, front: 3.75, side: 1.2, corner: 2.25)
		+ Model([
			box(length: 6, width: 2.7, z: 15 ... 18, x: -3, y: -6.45, tone: Tone.cargo),
			cylinder(at: at(-4.5, 2.7, 19.5), radius: 1.35, length: 2.25, axis: .z, tone: Tone.glass),
		] + sides(9.75) { armour(length: 33, width: 1.2, z: 5.25 ... 11.25, y: $0,
			front: 3, corner: 0.3, tone: Tone.turret) })
		+ cannon(from: at(2.25, 0, 15.75), to: at(22.5, 0, 16.5), caliber: 2.1)
	}

	static var m35: Model {
		bonnetTruck(ural: false) + Model([
			box(length: 21, width: 14.25, z: 6 ... 7.2, x: -8.25, tone: Tone.turret),
			box(length: 1.05, width: 14.25, z: 7.2 ... 10.8, x: -18.3, tone: Tone.cargo),
		] + sides(6.6) { box(length: 21, width: 1.05, z: 7.2 ... 10.8, x: -8.25, y: $0, tone: Tone.cargo) }
		+ [-13.5, -6].flatMap { x in
			sides(3) { box(length: 5.55, width: 4.5, z: 7.2 ... 11.7, x: x, y: $0, tone: Tone.body) }
		}, lines: sides(7.2) {
			Line(from: at(-18, $0, 9), to: at(1.5, $0, 9), tone: 115)
		})
	}

	static var ural4320: Model {
		bonnetTruck(ural: true) + canvasBed(length: 21.75, width: 15, x: -7.5, roof: 16.8)
		+ Model([
			cylinder(at: at(2.25, -7.95, 10.8), radius: 3, length: 1.8, axis: .y, tone: 44),
			cylinder(at: at(2.25, -9, 10.8), radius: 1.5, length: 0.3, axis: .y, tone: 110),
		])
	}

	static var m777: Model {
		wheeled(at: [-3], width: 12.75, radius: 3)
		+ Model([
			cylinder(at: at(0, 0, 3.75), radius: 3.75, length: 1.5, axis: .z, tone: Tone.turret),
			barrel(from: at(-6, 0, 5.25), to: at(4.5, 0, 11.25), caliber: 3.75, tone: Tone.turret),
		] + sides(1) { sign in
			prism([(-15, sign * 9 - 1.05), (0, sign * 3 - 1.05), (0, sign * 3 + 1.05),
				(-15, sign * 9 + 1.05)], z: 0 ... 1.8, tone: Tone.running)
		} + sides(7.95) { box(length: 6, width: 3, z: 0 ... 1.8, x: 4.5, y: $0, tone: Tone.turret) })
		+ cannon(from: at(3, 0, 10.5), to: at(25.5, 0, 27), caliber: 2.1, muzzle: true)
	}

	static var d30: Model {
		wheeled(at: [-1.5], width: 12, radius: 3)
		+ Model([
			cylinder(at: at(0, 0, 4.2), radius: 4.2, length: 3, axis: .z, tone: Tone.turret),
			box(length: 21, width: 2.25, z: 0 ... 1.8, x: 9, tone: Tone.running),
			armour(length: 2.1, width: 14.25, z: 5.25 ... 11.25, x: 2.25, side: 1.2,
				corner: 0.9, tone: Tone.body),
		] + sides(1) { sign in
			prism([(-15, sign * 9 - 0.9), (0, -0.9), (0, 0.9), (-15, sign * 9 + 0.9)],
				z: 0 ... 2.1, tone: Tone.running)
		}) + cannon(from: at(1.5, 0, 8.25), to: at(21, 0, 22.5), caliber: 1.95, muzzle: true)
	}

	static var m198: Model {
		fh70 + Model([
			box(length: 4.5, width: 3.75, z: 7.5 ... 10.8, x: -6, y: -3, tone: Tone.turret),
			barrel(from: at(4.5, 2.25, 11.25), to: at(19.5, 2.25, 21.6), caliber: 1.2, tone: Tone.cargo),
		])
	}

	static var d20: Model {
		fh70 + Model([
			armour(length: 2.25, width: 15, z: 5.25 ... 14.25, x: 0.75,
				side: 1.05, corner: 0.75, tone: Tone.body),
			box(length: 5.25, width: 5.25, z: 0 ... 2.25, x: -18, tone: Tone.turret),
		])
	}

	static var m109: Model {
		tracked(length: 36, width: 19.5, count: 7)
		+ Model([armour(length: 34.5, width: 17.25, z: 5.7 ... 10.2,
			front: 5.25, rear: 0.75, corner: 1.2, tone: Tone.body)])
		+ turret(length: 18, width: 15.75, z: 10.5 ... 18.9, x: -4.5, front: 0.75, side: 0.6, corner: 1.2)
		+ Model([
			hatch(x: -6, y: 3.6, z: 18.9, radius: 2.25),
			box(length: 1.8, width: 10.5, z: 1.5 ... 7.5, x: -17.25, tone: Tone.running),
		], lines: grille(x: 9, z: 10.35, length: 6, width: 9))
		+ cannon(from: at(3.75, 0, 15), to: at(25.5, 0, 26.25), caliber: 2.55, muzzle: true)
	}

	static var akatsiya: Model {
		tracked(length: 34.5, width: 19.5, count: 6)
		+ Model([armour(length: 33, width: 17.25, z: 5.7 ... 9.3,
			front: 6, rear: 0.9, corner: 1.2, tone: Tone.body)])
		+ turret(length: 15, width: 15, z: 9.6 ... 15.9, x: -5.25, front: 1.95, side: 1.5, corner: 3)
		+ Model([
			hatch(x: -6.75, y: 3, z: 15.9, radius: 2.1),
			box(length: 4.5, width: 4.5, z: 11.25 ... 14.25, x: 1.5, tone: Tone.turret),
		], lines: grille(x: 7.5, y: -2.25, z: 9.45, length: 6, width: 7.5))
		+ cannon(from: at(1.5, 0, 12.75), to: at(22.5, 0, 24), caliber: 2.55, muzzle: true)
	}

	static var m270: Model {
		tracked(length: 37.5, width: 19.5, count: 6)
		+ Model([
			box(length: 36, width: 16.5, z: 5.7 ... 7.5, tone: Tone.running),
			armour(length: 10.5, width: 16.5, z: 7.5 ... 15.75, x: 12.75, front: 2.1,
				corner: 1.05, tone: Tone.body),
			box(length: 0.6, width: 13.2, z: 11.7 ... 14.55, x: 17.85, tone: Tone.glass),
			cylinder(at: at(-7.5, 0, 9.3), radius: 4.5, length: 3, axis: .z, tone: Tone.running),
		]) + rocketPod(from: at(-16.5, 0, 10.5), to: at(1.5, 0, 21), rows: 2, columns: 6, spacing: 2.55)
	}

	static var bm21: Model {
		bonnetTruck(ural: true)
		+ Model([cylinder(at: at(-7.5, 0, 7.8), radius: 3.75, length: 2.25, axis: .z, tone: Tone.running)])
		+ rocketPod(from: at(-16.5, 0, 10.5), to: at(0, 0, 19.5), rows: 4, columns: 10, spacing: 1.275, open: true)
	}

	static var nasams: Model {
		wheeled(at: [-7.5], width: 13.5, radius: 3)
		+ Model([
			box(length: 27, width: 13.5, z: 3.45 ... 4.95, x: -1.5, tone: Tone.running),
			box(length: 10.5, width: 2.25, z: 1.95 ... 3.45, x: 15, tone: Tone.running),
			cylinder(at: at(-3, 0, 6), radius: 3, length: 3, axis: .z, tone: Tone.turret),
		] + sides(9) { box(length: 4.5, width: 3, z: 0 ... 1.5, x: 1.5, y: $0, tone: Tone.running) })
		+ rocketPod(from: at(-13.5, 0, 8.25), to: at(6, 0, 21.75), rows: 2, columns: 3, spacing: 3.75)
	}

	static var patriot: Model {
		wheeled(at: [-13.5, -6, 7.5, 15], width: 16.5, radius: 3.15)
		+ Model([
			box(length: 39, width: 15, z: 3.75 ... 6, tone: Tone.running),
			armour(length: 9, width: 14.7, z: 6 ... 14.25, x: 15, front: 0.75, corner: 0.75, tone: Tone.body),
			box(length: 0.45, width: 10.5, z: 10.2 ... 13.05, x: 19.2, tone: Tone.glass),
		]) + rocketPod(from: at(-16.5, 0, 9), to: at(1.5, 0, 22.5), rows: 2, columns: 2, spacing: 6.3)
	}

	static var neva: Model {
		wheeled(at: [-9, 7.5], width: 13.5, radius: 3)
		+ Model([
			box(length: 31.5, width: 12, z: 3.75 ... 5.25, tone: Tone.running),
			cylinder(at: at(-3, 0, 7.5), radius: 3.45, length: 4.5, axis: .z, tone: Tone.turret),
		] + sides(4.5) { barrel(from: at(-13.5, $0, 9), to: at(9, $0, 24), caliber: 2.4, tone: Tone.cargo) }
		+ sides(4.5) { box(length: 4.8, width: 5.4, z: 12.75 ... 13.8, x: -7.5, y: $0, tone: Tone.turret) },
		lines: sides(4.5) { Line(from: at(-15, $0, 7.5), to: at(7.5, $0, 22.5), tone: Tone.running, width: 2) })
	}

	static var s300: Model {
		wheeled(at: [-15, -6, 6, 15], width: 18, radius: 3.3)
		+ Model([
			box(length: 40.5, width: 15, z: 3.75 ... 6.75, tone: Tone.running),
			armour(length: 9.75, width: 16.5, z: 6.75 ... 15, x: 15.75,
				front: 0.6, corner: 0.75, tone: Tone.body),
			box(length: 0.6, width: 12, z: 11.25 ... 13.8, x: 20.4, tone: Tone.glass),
		] + [-12, -4.5].flatMap { x in
			sides(3.75) { cylinder(at: at(x, $0, 18), radius: 3.15, length: 22.5, axis: .z, tone: Tone.cargo) }
		})
	}

	static var lvkv90: Model {
		strf90 + Model([
			cylinder(at: at(-7.2, 0, 18.6), radius: 0.975, length: 6, axis: .z, tone: Tone.barrel),
			cylinder(at: at(-7.2, 0, 21.3), radius: 3, length: 3, axis: .z, tone: Tone.glass),
		])
	}

	static var m163: Model {
		tracked(length: 30, width: 18, count: 5)
		+ Model([armour(length: 28.5, width: 15.75, z: 5.7 ... 12.3,
			front: 6, corner: 1.05, tone: Tone.body)])
		+ turret(length: 9, width: 9, z: 12.6 ... 17.25, x: -1.5, corner: 1.5)
		+ gatling(from: at(1.5, 0, 15), to: at(13.5, 0, 22.8))
		+ Model([cylinder(at: at(-3, -5.25, 19.05), radius: 2.25, length: 1.2, axis: .x, tone: Tone.glass)])
	}

	static var tunguska: Model {
		tracked(length: 37.5, width: 21, count: 6)
		+ Model([
			armour(length: 36, width: 18.75, z: 5.7 ... 9.3, front: 6, corner: 1.5, tone: Tone.body),
			cylinder(at: at(-8.25, 0, 19.5), radius: 3.45, length: 1.8, axis: .x, tone: Tone.glass),
			box(length: 1.5, width: 1.5, z: 13.5 ... 19.5, x: -8.25, tone: Tone.barrel),
		]) + turret(length: 15, width: 12, z: 9.6 ... 15.75, x: -2.25, corner: 2.25)
		+ Model(sides(6.3) { barrel(from: at(0, $0, 13.5), to: at(21, $0, 18.75), caliber: 1.5, tone: Tone.barrel) }
		+ sides(9) { barrel(from: at(-9, $0, 15.75), to: at(7.5, $0, 19.5), caliber: 3.6, tone: Tone.cargo) })
	}

	static var m167: Model {
		wheeled(at: [-4.5], width: 13.5, radius: 3)
		+ Model([
			box(length: 19.5, width: 11.25, z: 2.4 ... 4.05, x: -1.5, tone: Tone.running),
			cylinder(at: at(0, 0, 5.25), radius: 4.65, length: 3, axis: .z, tone: Tone.turret),
			box(length: 5.25, width: 3.75, z: 4.5 ... 9.75, x: -4.5, y: 3.75, tone: Tone.body),
		] + sides(8.25) { box(length: 3, width: 3, z: 0 ... 1.8, x: 6, y: $0, tone: Tone.running) })
		+ gatling(from: at(0, 0, 7.5), to: at(12, 0, 22.5))
	}

	static var zu23: Model {
		wheeled(at: [-3], width: 13.5, radius: 2.7)
		+ Model([
			box(length: 15, width: 12, z: 2.25 ... 3.75, tone: Tone.running),
			cylinder(at: at(0, 0, 4.95), radius: 3.75, length: 2.7, axis: .z, tone: Tone.turret),
		] + sides(3.75) { box(length: 5.25, width: 3, z: 6 ... 9.45, x: -1.5, y: $0, tone: Tone.cargo) }
		+ sides(1.95) { barrel(from: at(0, $0, 8.25), to: at(16.5, $0, 21), caliber: 1.35, tone: Tone.barrel) },
		lines: sides(4.8) { Line(from: at(-6, $0, 4.5), to: at(-6, $0, 9), tone: Tone.antenna) })
	}
}

extension Units {

	static func ifvHull(length: Float, width: Float, deck: Float, front: Float) -> Model {
		tracked(length: length, width: width, count: 6)
		+ Model([
			armour(length: length - 1.5, width: width - 2.25, z: 5.7 ... deck,
				front: front, rear: 0.75, side: 0.9, corner: 1.5, tone: Tone.body),
			hatch(x: -length / 2 + 6, y: 3.3, z: deck, radius: 1.95),
			hatch(x: 7.5, y: -3.75, z: deck),
		], lines: grille(x: 7.5, y: 3.3, z: deck + 0.15, length: 6, width: 4.5))
	}

	static func bonnetTruck(ural: Bool) -> Model {
		let roof: Float = ural ? 15 : 13.5
		return wheeled(at: [-13.5, -5.25, 13.5], width: 15, radius: ural ? 3.45 : 3.15)
		+ Model([
			box(length: 39, width: 12, z: 3.75 ... 6, tone: Tone.running),
			armour(length: 9, width: 13.5, z: 6 ... roof, x: 6.75,
				front: 0.9, side: 0.45, corner: 0.75, tone: Tone.body),
			armour(length: 9, width: 11.25, z: 6 ... 10.2, x: 15,
				front: 0.75, side: 0.75, corner: 0.9, tone: Tone.body),
			box(length: 0.45, width: 10.95, z: roof - 3.3 ... roof - 0.75, x: 10.725, tone: Tone.glass),
			box(length: 0.45, width: 9, z: 6.75 ... 9.3, x: 19.2, tone: Tone.running),
			box(length: 1.5, width: 15.75, z: 4.5 ... 5.7, x: 19.5, tone: Tone.turret),
		] + sides(6.6) { box(length: 5.25, width: 0.375, z: roof - 3.45 ... roof - 0.75,
			x: 7.2, y: $0, tone: Tone.glass) }, lines: [
			Line(from: at(11.1, 0, roof - 3.3), to: at(10.725, 0, roof - 0.6), tone: Tone.body),
		] + sides(6.9) { Line(from: at(4.5, $0, 6.3), to: at(4.5, $0, roof - 1.5), tone: 105) })
	}

	static func canvasBed(length: Float, width: Float, x: Float, roof: Float) -> Model {
		Model([
			box(length: length, width: width + 0.6, z: 6 ... 7.2, x: x, tone: Tone.turret),
			armour(length: length, width: width, z: 7.2 ... roof, x: x,
				side: 1.5, corner: 0.75, tone: Tone.cargo),
		], lines: stride(from: x - length / 2 + 3, to: x + length / 2, by: 5.25).map {
			Line(from: at($0, -width / 2 + 1.5, roof + 0.15), to: at($0, width / 2 - 1.5, roof + 0.15), tone: 145)
		})
	}

	static func rocketPod(from start: V3, to end: V3, rows: Int, columns: Int, spacing: Float, open: Bool = false) -> Model {
		let axis = (end - start).normalized
		let across = V3(-axis.z, 0, axis.x)
		var solids: [Solid] = []
		for row in 0 ..< rows {
			for column in 0 ..< columns {
				let offset = across * ((Float(row) - Float(rows - 1) / 2) * spacing)
					+ V3(0, (Float(column) - Float(columns - 1) / 2) * spacing, 0)
				let tip = end + offset
				solids += [
					barrel(from: tip + axis * 0.075, to: tip + axis * 0.375,
						caliber: spacing * 0.58, tone: 45),
					barrel(from: start + offset, to: tip, caliber: spacing * 0.9,
						tone: open ? Tone.turret : Tone.cargo),
				]
			}
		}
		return Model(solids)
	}

	static func gatling(from start: V3, to end: V3) -> Model {
		let axis = (end - start).normalized
		return Model([
			barrel(from: start, to: end, caliber: 3.15, tone: Tone.barrel),
			barrel(from: start, to: start + axis * 4.5, caliber: 4.95, tone: Tone.turret),
		], lines: sides(1.2) { Line(from: start + V3(0, $0, 0.9), to: end + V3(0, $0, 0.9), tone: 70) })
	}
}
