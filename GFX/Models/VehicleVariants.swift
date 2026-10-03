public extension Units {

	static var m1117: Model {
		wheeled(at: [-6.5, 6.5], width: 10.5, radius: 2.4)
		+ Model([
			armour(length: 21, width: 10.5, z: 3.5 ... 8, front: 4.5, rear: 2.5,
				side: 1, corner: 1.3, tone: Tone.body),
			box(length: 0.7, width: 6, z: 6.5 ... 7.8, x: 6, tone: Tone.glass),
			hatch(x: -6.5, y: -2.5, z: 8),
		], lines: sides(5) { Line(from: at(-1, $0, 4.3), to: at(-1, $0, 7.5), tone: 100) })
		+ turret(length: 6, width: 6, z: 8.2 ... 11, x: -1, corner: 1.3)
		+ cannon(from: at(1, 0, 9.7), to: at(7.5, 0, 10), caliber: 1.3)
	}

	static var stryker: Model {
		wheeled(at: [-9, -3.3, 3.3, 9], width: 11.5, radius: 2.1)
		+ Model([
			armour(length: 25, width: 11.5, z: 3.8 ... 8, front: 5, rear: 0.6,
				side: 1, corner: 1.4, tone: Tone.body),
			hatch(x: -7, y: 2.5, z: 8, radius: 1.4),
			hatch(x: 4, y: -2.5, z: 8),
			box(length: 4, width: 2, z: 8 ... 8.6, x: -4.5, y: -3, tone: Tone.cargo),
		], lines: grille(x: -7, y: -2.5, z: 8.1, length: 3.5, width: 3))
		+ turret(length: 3.5, width: 3.5, z: 8.3 ... 11, x: 1, corner: 0.7)
		+ cannon(from: at(2, 0, 10), to: at(7, 0, 10.3), caliber: 0.9)
	}

	static var btr80: Model {
		wheeled(at: [-9, -3.2, 3.2, 9], width: 11, radius: 2.3)
		+ Model([
			armour(length: 26, width: 11, z: 3.5 ... 7.2, front: 6, rear: 2,
				side: 1.3, corner: 1.6, tone: Tone.body),
			hatch(x: -6, y: -2.5, z: 7.2), hatch(x: -6, y: 2.5, z: 7.2),
			box(length: 1, width: 6, z: 6.3 ... 7.2, x: 6.7, tone: Tone.glass),
		], lines: grille(x: -9, z: 7.3, length: 3, width: 5))
		+ turret(length: 4.5, width: 4.5, z: 7.4 ... 10, x: 1.3, side: 1.2, corner: 1)
		+ cannon(from: at(3, 0, 8.7), to: at(10, 0, 9), caliber: 1)
	}

	static var fv432: Model {
		tracked(length: 21, width: 12, count: 5)
		+ Model([
			armour(length: 20, width: 10.5, z: 3.8 ... 9.2, front: 2.5, rear: 0.3,
				side: 0.2, corner: 0.5, tone: Tone.body),
			hatch(x: -4, z: 9.2, radius: 2.2), hatch(x: 3, y: -2, z: 9.2),
			cylinder(at: at(-2, 2.8, 9.9), radius: 1.3, length: 1, axis: .z, tone: Tone.turret),
			barrel(from: at(-1, 2.8, 10.2), to: at(5, 2.8, 10.3), caliber: 0.7, tone: Tone.barrel),
			box(length: 8, width: 0.7, z: 6 ... 7, x: -1, y: -5.5, tone: Tone.cargo),
		], lines: grille(x: 3, y: 2, z: 9.3, length: 4, width: 3))
	}

	static var mtLb: Model {
		tracked(length: 23, width: 11.5, count: 6)
		+ Model([
			armour(length: 22, width: 10, z: 3.8 ... 6.7, front: 5, rear: 0.8,
				side: 0.4, corner: 0.8, tone: Tone.body),
			hatch(x: -7, y: -2, z: 6.7), hatch(x: -3.5, y: -2, z: 6.7),
			cylinder(at: at(4, 2.1, 7.4), radius: 1.5, length: 1.2, axis: .z, tone: Tone.turret),
			barrel(from: at(5, 2.1, 7.8), to: at(9, 2.1, 8), caliber: 0.7, tone: Tone.barrel),
		], lines: grille(x: -4, y: 2.1, z: 6.8, length: 5, width: 3))
	}

	static var m2A2: Model {
		ifvHull(length: 23, width: 13, deck: 8.3, front: 4.2)
		+ turret(length: 8.5, width: 7.5, z: 8.5 ... 12, x: -1, y: -0.8, front: 1.8, corner: 1.4)
		+ Model([
			hatch(x: -2, y: 0.8, z: 12),
			box(length: 5, width: 2.2, z: 9.5 ... 12, x: -1, y: 4.3, tone: Tone.cargo),
			box(length: 1.2, width: 2, z: 11 ... 12.8, x: 1.3, y: -2, tone: Tone.glass),
		]) + cannon(from: at(2.4, -0.8, 10.4), to: at(13.5, -0.8, 10.8), caliber: 1.2)
	}

	static var marder: Model {
		ifvHull(length: 24, width: 12.5, deck: 8.6, front: 5.5)
		+ turret(length: 6.5, width: 5.5, z: 8.8 ... 11, x: 0.5, front: 1.5, corner: 1)
		+ Model([
			hatch(x: -6, y: 1.5, z: 8.6, radius: 1.4),
			barrel(from: at(-1, 2.4, 11.7), to: at(4, 2.4, 12.1), caliber: 1.4, tone: Tone.cargo),
			armour(length: 3.5, width: 3.2, z: 8.7 ... 10.5, x: -7, corner: 0.6, tone: Tone.turret),
		]) + cannon(from: at(3, 0, 10), to: at(13, 0, 10.5), caliber: 1)
	}

	static var bmp2: Model {
		ifvHull(length: 24, width: 12, deck: 6.5, front: 6)
		+ turret(length: 6.5, width: 6.5, z: 6.7 ... 9.4, x: -2, side: 1.1, corner: 1.5)
		+ Model([
			hatch(x: -3, y: 1.3, z: 9.4),
			barrel(from: at(-2, 0, 10), to: at(3, 0, 10.3), caliber: 1.1, tone: Tone.running),
			box(length: 10, width: 0.6, z: 5.8 ... 6.7, x: -4.5, y: 5.7, tone: Tone.cargo),
		]) + cannon(from: at(0.5, 0, 8.2), to: at(14, 0, 8.8), caliber: 1)
	}

	static var cv9035: Model {
		ifvHull(length: 22, width: 12.5, deck: 7.5, front: 4.5)
		+ turret(length: 8.5, width: 7.8, z: 7.7 ... 11.2, x: -2, front: 2, corner: 1.7)
		+ Model([
			hatch(x: -3, y: 1.4, z: 11.2),
			box(length: 2, width: 2, z: 11.2 ... 12.6, x: -0.5, y: -2, tone: Tone.glass),
		]) + cannon(from: at(1.2, 0, 9.5), to: at(13, 0, 10), caliber: 1.4)
	}

	static var kf41: Model {
		ifvHull(length: 25, width: 13.5, deck: 9, front: 5)
		+ turret(length: 9.5, width: 8, z: 9.2 ... 12.2, x: -2, front: 2.5, side: 0.8, corner: 1.5)
		+ Model([
			box(length: 4, width: 1.8, z: 10 ... 12, x: -2, y: -4.3, tone: Tone.cargo),
			cylinder(at: at(-3, 1.8, 13), radius: 0.9, length: 1.5, axis: .z, tone: Tone.glass),
		] + sides(6.5) { armour(length: 22, width: 0.8, z: 3.5 ... 7.5, y: $0,
			front: 2, corner: 0.2, tone: Tone.turret) })
		+ cannon(from: at(1.5, 0, 10.5), to: at(15, 0, 11), caliber: 1.4)
	}

	static var m35: Model {
		bonnetTruck(ural: false) + Model([
			box(length: 14, width: 9.5, z: 4 ... 4.8, x: -5.5, tone: Tone.turret),
			box(length: 0.7, width: 9.5, z: 4.8 ... 7.2, x: -12.2, tone: Tone.cargo),
		] + sides(4.4) { box(length: 14, width: 0.7, z: 4.8 ... 7.2, x: -5.5, y: $0, tone: Tone.cargo) }
		+ [-9, -4].flatMap { x in
			sides(2) { box(length: 3.7, width: 3, z: 4.8 ... 7.8, x: x, y: $0, tone: Tone.body) }
		}, lines: sides(4.8) {
			Line(from: at(-12, $0, 6), to: at(1, $0, 6), tone: 115)
		})
	}

	static var ural4320: Model {
		bonnetTruck(ural: true) + canvasBed(length: 14.5, width: 10, x: -5, roof: 11.2)
		+ Model([
			cylinder(at: at(1.5, -5.3, 7.2), radius: 2, length: 1.2, axis: .y, tone: 44),
			cylinder(at: at(1.5, -6, 7.2), radius: 1, length: 0.2, axis: .y, tone: 110),
		])
	}

	static var m777: Model {
		wheeled(at: [-2], width: 8.5, radius: 2)
		+ Model([
			cylinder(at: at(0, 0, 2.5), radius: 2.5, length: 1, axis: .z, tone: Tone.turret),
			barrel(from: at(-4, 0, 3.5), to: at(3, 0, 7.5), caliber: 2.5, tone: Tone.turret),
		] + sides(1) { sign in
			prism([(-10, sign * 6 - 0.7), (0, sign * 2 - 0.7), (0, sign * 2 + 0.7),
				(-10, sign * 6 + 0.7)], z: 0 ... 1.2, tone: Tone.running)
		} + sides(5.3) { box(length: 4, width: 2, z: 0 ... 1.2, x: 3, y: $0, tone: Tone.turret) })
		+ cannon(from: at(2, 0, 7), to: at(17, 0, 18), caliber: 1.4, muzzle: true)
	}

	static var d30: Model {
		wheeled(at: [-1], width: 8, radius: 2)
		+ Model([
			cylinder(at: at(0, 0, 2.8), radius: 2.8, length: 2, axis: .z, tone: Tone.turret),
			box(length: 14, width: 1.5, z: 0 ... 1.2, x: 6, tone: Tone.running),
			armour(length: 1.4, width: 9.5, z: 3.5 ... 7.5, x: 1.5, side: 0.8,
				corner: 0.6, tone: Tone.body),
		] + sides(1) { sign in
			prism([(-10, sign * 6 - 0.6), (0, -0.6), (0, 0.6), (-10, sign * 6 + 0.6)],
				z: 0 ... 1.4, tone: Tone.running)
		}) + cannon(from: at(1, 0, 5.5), to: at(14, 0, 15), caliber: 1.3, muzzle: true)
	}

	static var m198: Model {
		fh70 + Model([
			box(length: 3, width: 2.5, z: 5 ... 7.2, x: -4, y: -2, tone: Tone.turret),
			barrel(from: at(3, 1.5, 7.5), to: at(13, 1.5, 14.4), caliber: 0.8, tone: Tone.cargo),
		])
	}

	static var d20: Model {
		fh70 + Model([
			armour(length: 1.5, width: 10, z: 3.5 ... 9.5, x: 0.5,
				side: 0.7, corner: 0.5, tone: Tone.body),
			box(length: 3.5, width: 3.5, z: 0 ... 1.5, x: -12, tone: Tone.turret),
		])
	}

	static var m109: Model {
		tracked(length: 24, width: 13, count: 7)
		+ Model([armour(length: 23, width: 11.5, z: 3.8 ... 6.8,
			front: 3.5, rear: 0.5, corner: 0.8, tone: Tone.body)])
		+ turret(length: 12, width: 10.5, z: 7 ... 12.6, x: -3, front: 0.5, side: 0.4, corner: 0.8)
		+ Model([
			hatch(x: -4, y: 2.4, z: 12.6, radius: 1.5),
			box(length: 1.2, width: 7, z: 1 ... 5, x: -11.5, tone: Tone.running),
		], lines: grille(x: 6, z: 6.9, length: 4, width: 6))
		+ cannon(from: at(2.5, 0, 10), to: at(17, 0, 17.5), caliber: 1.7, muzzle: true)
	}

	static var akatsiya: Model {
		tracked(length: 23, width: 13, count: 6)
		+ Model([armour(length: 22, width: 11.5, z: 3.8 ... 6.2,
			front: 4, rear: 0.6, corner: 0.8, tone: Tone.body)])
		+ turret(length: 10, width: 10, z: 6.4 ... 10.6, x: -3.5, front: 1.3, side: 1, corner: 2)
		+ Model([
			hatch(x: -4.5, y: 2, z: 10.6, radius: 1.4),
			box(length: 3, width: 3, z: 7.5 ... 9.5, x: 1, tone: Tone.turret),
		], lines: grille(x: 5, y: -1.5, z: 6.3, length: 4, width: 5))
		+ cannon(from: at(1, 0, 8.5), to: at(15, 0, 16), caliber: 1.7, muzzle: true)
	}

	static var m270: Model {
		tracked(length: 25, width: 13, count: 6)
		+ Model([
			box(length: 24, width: 11, z: 3.8 ... 5, tone: Tone.running),
			armour(length: 7, width: 11, z: 5 ... 10.5, x: 8.5, front: 1.4,
				corner: 0.7, tone: Tone.body),
			box(length: 0.4, width: 8.8, z: 7.8 ... 9.7, x: 11.9, tone: Tone.glass),
			cylinder(at: at(-5, 0, 6.2), radius: 3, length: 2, axis: .z, tone: Tone.running),
		]) + rocketPod(from: at(-11, 0, 7), to: at(1, 0, 14), rows: 2, columns: 6, spacing: 1.7)
	}

	static var bm21: Model {
		bonnetTruck(ural: true)
		+ Model([cylinder(at: at(-5, 0, 5.2), radius: 2.5, length: 1.5, axis: .z, tone: Tone.running)])
		+ rocketPod(from: at(-11, 0, 7), to: at(0, 0, 13), rows: 4, columns: 10, spacing: 0.85, open: true)
	}

	static var nasams: Model {
		wheeled(at: [-5], width: 9, radius: 2)
		+ Model([
			box(length: 18, width: 9, z: 2.3 ... 3.3, x: -1, tone: Tone.running),
			box(length: 7, width: 1.5, z: 1.3 ... 2.3, x: 10, tone: Tone.running),
			cylinder(at: at(-2, 0, 4), radius: 2, length: 2, axis: .z, tone: Tone.turret),
		] + sides(6) { box(length: 3, width: 2, z: 0 ... 1, x: 1, y: $0, tone: Tone.running) })
		+ rocketPod(from: at(-9, 0, 5.5), to: at(4, 0, 14.5), rows: 2, columns: 3, spacing: 2.5)
	}

	static var patriot: Model {
		wheeled(at: [-9, -4, 5, 10], width: 11, radius: 2.1)
		+ Model([
			box(length: 26, width: 10, z: 2.5 ... 4, tone: Tone.running),
			armour(length: 6, width: 9.8, z: 4 ... 9.5, x: 10, front: 0.5, corner: 0.5, tone: Tone.body),
			box(length: 0.3, width: 7, z: 6.8 ... 8.7, x: 12.8, tone: Tone.glass),
		]) + rocketPod(from: at(-11, 0, 6), to: at(1, 0, 15), rows: 2, columns: 2, spacing: 4.2)
	}

	static var neva: Model {
		wheeled(at: [-6, 5], width: 9, radius: 2)
		+ Model([
			box(length: 21, width: 8, z: 2.5 ... 3.5, tone: Tone.running),
			cylinder(at: at(-2, 0, 5), radius: 2.3, length: 3, axis: .z, tone: Tone.turret),
		] + sides(3) { barrel(from: at(-9, $0, 6), to: at(6, $0, 16), caliber: 1.6, tone: Tone.cargo) }
		+ sides(3) { box(length: 3.2, width: 3.6, z: 8.5 ... 9.2, x: -5, y: $0, tone: Tone.turret) },
		lines: sides(3) { Line(from: at(-10, $0, 5), to: at(5, $0, 15), tone: Tone.running, width: 2) })
	}

	static var s300: Model {
		wheeled(at: [-10, -4, 4, 10], width: 12, radius: 2.2)
		+ Model([
			box(length: 27, width: 10, z: 2.5 ... 4.5, tone: Tone.running),
			armour(length: 6.5, width: 11, z: 4.5 ... 10, x: 10.5,
				front: 0.4, corner: 0.5, tone: Tone.body),
			box(length: 0.4, width: 8, z: 7.5 ... 9.2, x: 13.6, tone: Tone.glass),
		] + [-8, -3].flatMap { x in
			sides(2.5) { cylinder(at: at(x, $0, 12), radius: 2.1, length: 15, axis: .z, tone: Tone.cargo) }
		})
	}

	static var lvkv90: Model {
		strf90 + Model([
			cylinder(at: at(-4.8, 0, 12.4), radius: 0.65, length: 4, axis: .z, tone: Tone.barrel),
			cylinder(at: at(-4.8, 0, 14.2), radius: 2, length: 2, axis: .z, tone: Tone.glass),
		])
	}

	static var m163: Model {
		tracked(length: 20, width: 12, count: 5)
		+ Model([armour(length: 19, width: 10.5, z: 3.8 ... 8.2,
			front: 4, corner: 0.7, tone: Tone.body)])
		+ turret(length: 6, width: 6, z: 8.4 ... 11.5, x: -1, corner: 1)
		+ gatling(from: at(1, 0, 10), to: at(9, 0, 15.2))
		+ Model([cylinder(at: at(-2, -3.5, 12.7), radius: 1.5, length: 0.8, axis: .x, tone: Tone.glass)])
	}

	static var tunguska: Model {
		tracked(length: 25, width: 14, count: 6)
		+ Model([
			armour(length: 24, width: 12.5, z: 3.8 ... 6.2, front: 4, corner: 1, tone: Tone.body),
			cylinder(at: at(-5.5, 0, 13), radius: 2.3, length: 1.2, axis: .x, tone: Tone.glass),
			box(length: 1, width: 1, z: 9 ... 13, x: -5.5, tone: Tone.barrel),
		]) + turret(length: 10, width: 8, z: 6.4 ... 10.5, x: -1.5, corner: 1.5)
		+ Model(sides(4.2) { barrel(from: at(0, $0, 9), to: at(14, $0, 12.5), caliber: 1, tone: Tone.barrel) }
		+ sides(6) { barrel(from: at(-6, $0, 10.5), to: at(5, $0, 13), caliber: 2.4, tone: Tone.cargo) })
	}

	static var m167: Model {
		wheeled(at: [-3], width: 9, radius: 2)
		+ Model([
			box(length: 13, width: 7.5, z: 1.6 ... 2.7, x: -1, tone: Tone.running),
			cylinder(at: at(0, 0, 3.5), radius: 3.1, length: 2, axis: .z, tone: Tone.turret),
			box(length: 3.5, width: 2.5, z: 3 ... 6.5, x: -3, y: 2.5, tone: Tone.body),
		] + sides(5.5) { box(length: 2, width: 2, z: 0 ... 1.2, x: 4, y: $0, tone: Tone.running) })
		+ gatling(from: at(0, 0, 5), to: at(8, 0, 15))
	}

	static var zu23: Model {
		wheeled(at: [-2], width: 9, radius: 1.8)
		+ Model([
			box(length: 10, width: 8, z: 1.5 ... 2.5, tone: Tone.running),
			cylinder(at: at(0, 0, 3.3), radius: 2.5, length: 1.8, axis: .z, tone: Tone.turret),
		] + sides(2.5) { box(length: 3.5, width: 2, z: 4 ... 6.3, x: -1, y: $0, tone: Tone.cargo) }
		+ sides(1.3) { barrel(from: at(0, $0, 5.5), to: at(11, $0, 14), caliber: 0.9, tone: Tone.barrel) },
		lines: sides(3.2) { Line(from: at(-4, $0, 3), to: at(-4, $0, 6), tone: Tone.antenna) })
	}
}

extension Units {

	static func ifvHull(length: Float, width: Float, deck: Float, front: Float) -> Model {
		tracked(length: length, width: width, count: 6)
		+ Model([
			armour(length: length - 1, width: width - 1.5, z: 3.8 ... deck,
				front: front, rear: 0.5, side: 0.6, corner: 1, tone: Tone.body),
			hatch(x: -length / 2 + 4, y: 2.2, z: deck, radius: 1.3),
			hatch(x: 5, y: -2.5, z: deck),
		], lines: grille(x: 5, y: 2.2, z: deck + 0.1, length: 4, width: 3))
	}

	static func bonnetTruck(ural: Bool) -> Model {
		let roof: Float = ural ? 10 : 9
		return wheeled(at: [-9, -3.5, 9], width: 10, radius: ural ? 2.3 : 2.1)
		+ Model([
			box(length: 26, width: 8, z: 2.5 ... 4, tone: Tone.running),
			armour(length: 6, width: 9, z: 4 ... roof, x: 4.5,
				front: 0.6, side: 0.3, corner: 0.5, tone: Tone.body),
			armour(length: 6, width: 7.5, z: 4 ... 6.8, x: 10,
				front: 0.5, side: 0.5, corner: 0.6, tone: Tone.body),
			box(length: 0.3, width: 7.3, z: roof - 2.2 ... roof - 0.5, x: 7.15, tone: Tone.glass),
			box(length: 0.3, width: 6, z: 4.5 ... 6.2, x: 12.8, tone: Tone.running),
			box(length: 1, width: 10.5, z: 3 ... 3.8, x: 13, tone: Tone.turret),
		] + sides(4.4) { box(length: 3.5, width: 0.25, z: roof - 2.3 ... roof - 0.5,
			x: 4.8, y: $0, tone: Tone.glass) }, lines: [
			Line(from: at(7.4, 0, roof - 2.2), to: at(7.15, 0, roof - 0.4), tone: Tone.body),
		] + sides(4.6) { Line(from: at(3, $0, 4.2), to: at(3, $0, roof - 1), tone: 105) })
	}

	static func canvasBed(length: Float, width: Float, x: Float, roof: Float) -> Model {
		Model([
			box(length: length, width: width + 0.4, z: 4 ... 4.8, x: x, tone: Tone.turret),
			armour(length: length, width: width, z: 4.8 ... roof, x: x,
				side: 1, corner: 0.5, tone: Tone.cargo),
		], lines: stride(from: x - length / 2 + 2, to: x + length / 2, by: 3.5).map {
			Line(from: at($0, -width / 2 + 1, roof + 0.1), to: at($0, width / 2 - 1, roof + 0.1), tone: 145)
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
					barrel(from: tip + axis * 0.05, to: tip + axis * 0.25,
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
			barrel(from: start, to: end, caliber: 2.1, tone: Tone.barrel),
			barrel(from: start, to: start + axis * 3, caliber: 3.3, tone: Tone.turret),
		], lines: sides(0.8) { Line(from: start + V3(0, $0, 0.6), to: end + V3(0, $0, 0.6), tone: 70) })
	}
}
