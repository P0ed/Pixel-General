public extension Units {
	static var leo2a4: Model {
		let roof: Float = 15.9
		var turret = armour(length: 20.4, width: 17.4, z: 10.35 ... roof, x: -2.4,
			front: 0.45, rear: 0.3, side: 0.3, corner: 1.35, tone: Tone.turret)
		turret.planes += sides(1) { side in
			Plane(normal: V3(0, side, -0.85), through: at(0, side * 8.7, 11.7))
		}

		return leopardHull
		+ Model([
			turret,
			armour(length: 3.3, width: 5.1, z: 11.55 ... 15.15, x: 7.95,
				front: 0.45, side: 0.45, corner: 0.6, tone: Tone.cargo),
			box(length: 3.0, width: 1.8, z: 13.65 ... 14.85, x: 6.75, y: -4.8, tone: 80),
			box(length: 6.0, width: 4.8, z: roof ... 16.5, x: -9.45, y: -4.5, tone: Tone.cargo),
		], lines: sides(8.55) { y in
			Line(from: at(-9.6, y, 12.15), to: at(1.8, y, 12.15), tone: 64)
		})
		+ tankRoof(x: -3.45, z: roof)
		+ leopardGun(to: 29.25, z: 13.35)
	}

	static var leo2a7: Model {
		let roof: Float = 15.75
		return leopardHull
		+ leopardWedgeTurret(roof: roof, nose: 13.05, ridge: 12.6)
		+ Model([
			box(length: 5.7, width: 4.5, z: roof ... 16.65, x: 0.6, y: -4.65, tone: Tone.turret),
			box(length: 0.45, width: 3.3, z: 16.05 ... 16.65, x: 3.6, y: -4.65, tone: 90),
			box(length: 2.7, width: 2.7, z: roof ... 18.75, x: -4.65, y: -4.5, tone: Tone.glass),
		] + sides(8.55) {
			armour(length: 9.3, width: 1.5, z: 10.95 ... 15.15, x: -8.1, y: $0,
				front: 0.45, side: 0.3, corner: 0.6, tone: Tone.cargo)
		}, lines: [
			Line(from: at(-11.4, -5.4, roof), to: at(-12.3, -5.4, 21.3), tone: Tone.antenna),
		])
		+ tankRoof(x: -3.75, z: roof)
		+ leopardGun(to: 33.45, z: 13.35)
	}

	static var strv122: Model {
		let roof: Float = 16.2
		return leopardHull
		+ leopardWedgeTurret(roof: roof, nose: 11.85, ridge: 12.75)
		+ Model([
			armour(length: 13.5, width: 15.9, z: roof ... 17.25, x: -1.95,
				front: 2.85, rear: 0.45, side: 0.9, corner: 1.35, tone: Tone.turret),
			armour(length: 9.0, width: 19.2, z: 8.55 ... 10.65, x: 10.2,
				front: 3.6, rear: 0.3, side: 0.6, corner: 1.2, tone: Tone.body),
			box(length: 1.8, width: 3.3, z: 15.6 ... 17.1, x: 4.35, y: -4.5, tone: Tone.glass),
		] + sides(8.7) {
			armour(length: 3.45, width: 1.8, z: 12.45 ... 15.45, x: -6.15, y: $0,
				front: 0.3, side: 0.3, corner: 0.45, tone: Tone.running)
		})
		+ tankRoof(x: -3.15, z: 17.25)
		+ leopardGun(to: 29.25, z: 13.65)
	}
}

private extension Units {

	static var leopardHull: Model {
		var glacis = armour(length: 38.4, width: 21.6, z: 5.4 ... 9.6,
			front: 7.8, rear: 0.9, side: 0.45, corner: 1.5, tone: Tone.body)
		glacis.planes.append(Plane(normal: V3(1, 0, -1.1), through: at(17.7, 0, 6.6)))

		return tankChassis(length: 39, width: 22.5, wheels: 7, deck: 9.6)
		+ tankSkirts(length: 36, width: 22.5, z: 5.25 ... 8.85)
		+ Model([
			glacis,
			cylinder(at: at(-0.9, 0, 9.975), radius: 7.2, length: 0.75, axis: .z, tone: Tone.running),
		] + sides(8.7) {
			armour(length: 5.4, width: 4.2, z: 6.9 ... 8.85, x: 15.45, y: $0,
				front: 1.2, side: 0.15, corner: 0.75, tone: Tone.body)
		} + sides(8.1) {
			box(length: 0.75, width: 1.65, z: 7.55 ... 8.3, x: 17.55, y: $0, tone: Tone.glass)
		})
	}

	static func leopardWedgeTurret(roof: Float, nose: Float, ridge: Float) -> Model {
		let innerEdge: Float = 1.8
		let outerEdge: Float = 8.1
		let sweep: Float = 0.38
		let cheekWidth: Float = 7.8
		let cheekRear: Float = 2.4
		let cheeks = sides(1) { side in
			let tip = at(nose, side * innerEdge, ridge)
			let outerTip = at(nose - sweep * (outerEdge - innerEdge), side * outerEdge, ridge)
			var cheek = box(length: nose - cheekRear, width: cheekWidth, z: 10.35 ... roof,
				x: (nose + cheekRear) / 2, y: side * (innerEdge + cheekWidth / 2), tone: Tone.turret)
			cheek.planes += [
				Plane(normal: V3(1, side * sweep, 2.15), through: tip),
				Plane(normal: V3(1, side * sweep, -2.55), through: tip),
				Plane(normal: V3(0.26, side, 0.12), through: outerTip),
			]
			return (solid: cheek, edge: Line(from: tip, to: outerTip, tone: 108))
		}
		return Model([
			armour(length: 20.4, width: 17.4, z: 10.35 ... roof, x: -3.75,
				front: 0.75, rear: 0.45, side: 0.6, corner: 1.65, tone: Tone.turret),
			armour(length: 3.9, width: 3.45, z: 11.1 ... 15.3, x: 7.35,
				front: 0.6, side: 0.3, corner: 0.6, tone: Tone.cargo),
		] + cheeks.map(\.solid), lines: cheeks.map(\.edge))
	}

	static func leopardGun(to muzzle: Float, z: Float) -> Model {
		let base: Float = 8.4
		return Model(
			cylinder(at: at((base + muzzle) / 2, 0, z), radius: 1.05, length: muzzle - base, axis: .x, tone: Tone.barrel),
			cylinder(at: at(9.6, 0, z), radius: 1.35, length: 2.4, axis: .x, tone: Tone.barrel),
			cylinder(at: at(16.5, 0, z), radius: 1.65, length: 5.4, axis: .x, tone: Tone.barrel),
			cylinder(at: at(muzzle - 0.6, 0, z), radius: 1.2, length: 1.2, axis: .x, tone: Tone.turret)
		)
	}
}
