public extension Units {

	/// Leopard 1: cast turret, exposed suspension and a narrow gun mantlet.
	static var leo1: Model {
		tankChassis(length: 25, width: 14, wheels: 7, deck: 6.2)
		+ Model([
			tankPlate(length: 24, width: 12.5, z: 4.1 ... 6.2,
				front: 4.5, rear: 1, side: 0.6, corner: 1),
			tankPlate(length: 3, width: 3.5, z: 7.2 ... 9.2, x: 4,
				front: 0.7, rear: 0, side: 0.4, corner: 0.5, tone: Tone.turret),
		])
		+ tankTurret(length: 10.5, width: 10.5, z: 6.4 ... 9.6, x: -0.8,
			front: 2, rear: 1.5, side: 1.2, corner: 2.2)
		+ tankGun(from: 4.5, length: 15.5, z: 8.3, caliber: 1.4)
		+ tankRoof(x: -1.5, z: 9.6)
	}

	/// Abrams: long angular bustle, broad armour cheeks and seven road wheels behind skirts.
	static var m1A1: Model {
		tankChassis(length: 26, width: 15, wheels: 7, deck: 6.5)
		+ Model([
			tankPlate(length: 25, width: 13.5, z: 4.1 ... 6.5,
				front: 5, rear: 1, side: 0.5, corner: 1),
			tankPlate(length: 3, width: 3.5, z: 7.5 ... 9.9, x: 4.5,
				front: 0.5, rear: 0, side: 0.3, corner: 0.5, tone: Tone.turret),
		])
		+ tankTurret(length: 14, width: 11.5, z: 6.7 ... 10.6, x: -1.2,
			front: 2.4, rear: 0.8, side: 0.8, corner: 2.4)
		+ tankSkirts(length: 23, width: 15, z: 3.2 ... 5.8)
		+ tankGun(from: 5, length: 15, z: 8.9, caliber: 1.6)
		+ tankRoof(x: -1.5, z: 10.6)
	}

	/// T-72: six large road wheels, low glacis and a squat, faceted cast turret.
	static var t72: Model {
		tankChassis(length: 24, width: 14, wheels: 6, deck: 5.6)
		+ Model([
			tankPlate(length: 23, width: 12.5, z: 3.8 ... 5.6,
				front: 4.5, rear: 0.8, side: 0.7, corner: 1.2),
			tankPlate(length: 2.5, width: 3, z: 6.2 ... 8.4, x: 3.6,
				front: 0.5, rear: 0, side: 0.3, corner: 0.5, tone: Tone.turret),
		])
		+ tankTurret(length: 10, width: 11, z: 5.8 ... 8.7, x: -0.4,
			front: 2.2, rear: 1.6, side: 1.6, corner: 2.5)
		+ tankGun(from: 4, length: 16.5, z: 7.4, caliber: 1.4)
		+ tankRoof(x: -1.8, z: 8.7)
	}

	/// Leopard 2: long hull, a wide turret bustle and pointed, sloping frontal armour.
	static var leo2a6: Model {
		tankChassis(length: 26, width: 15, wheels: 7, deck: 6.6)
		+ Model([
			tankPlate(length: 25, width: 14, z: 4.1 ... 6.6,
				front: 5, rear: 1, side: 0.5, corner: 1),
			tankPlate(length: 3, width: 3.2, z: 7.5 ... 9.8, x: 5,
				front: 0.5, rear: 0, side: 0.3, corner: 0.5, tone: Tone.turret),
		] + sides(3.6) {
			tankPlate(length: 5, width: 4, z: 7 ... 10.3, x: 5.2, y: $0,
				front: 3.2, rear: 0, side: 0.3, corner: 0.7, tone: Tone.turret)
		})
		+ tankTurret(length: 12.5, width: 11.5, z: 6.8 ... 10.3, x: -0.8,
			front: 0.8, rear: 0.8, side: 0.5, corner: 1.8)
		+ tankSkirts(length: 23, width: 15, z: 3 ... 5.9)
		+ tankGun(from: 5.5, length: 16, z: 8.9, caliber: 1.6)
		+ tankRoof(x: -1.8, z: 10.3)
	}

	/// The T-72 chassis with reactive armour cheeks, a rear bustle and a raised sight.
	static var t90m: Model {
		t72 + Model([
			tankPlate(length: 4.5, width: 9, z: 6 ... 8.4, x: -6.2,
				front: 0, rear: 0.6, side: 0.4, corner: 0.8, tone: Tone.turret),
			GFX.box(length: 2.2, width: 2, z: 8.7 ... 10.3, x: 0, y: -2.6, tone: Tone.glass),
		] + sides(3.7) {
			tankPlate(length: 4.5, width: 3.2, z: 6.1 ... 8.8, x: 2.5, y: $0,
				front: 1.7, rear: 0.2, side: 0.4, corner: 0.8, tone: Tone.cargo)
		}) + tankSkirts(length: 21, width: 14, z: 2.8 ... 4.9)
	}

	/// Abrams with a visible bustle rack and an independent commander's thermal sight.
	static var m1A2: Model {
		m1A1 + Model([
			tankPlate(length: 3.5, width: 10.5, z: 7.5 ... 9.7, x: -9.3,
				front: 0, rear: 0, side: 0, corner: 0.7, tone: Tone.running),
			GFX.box(length: 2.4, width: 2.4, z: 10.6 ... 12.2, x: 0.6, y: -2.6, tone: Tone.glass),
		], lines: [-4, -2, 0, 2, 4].map {
			Line(from: at(-10.8, $0, 9.8), to: at(-8.3, $0, 9.8), tone: Tone.turret)
		})
	}

	/// Swedish Leopard with an armoured roof and reinforced frontal cheek modules.
	static var strv122: Model {
		leo2a6 + Model([
			tankPlate(length: 7, width: 7, z: 10.3 ... 11, x: -1,
				front: 0.3, rear: 0.3, side: 0.3, corner: 0.8, tone: Tone.cargo),
		] + sides(3.8) {
			tankPlate(length: 5.5, width: 4.2, z: 7 ... 10.6, x: 5.2, y: $0,
				front: 3.5, rear: 0, side: 0.3, corner: 0.8, tone: Tone.turret)
		}) + tankRoof(x: -1.8, z: 11)
	}
}

extension Units {

	static func tankTurret(
		length: Float, width: Float, z: ClosedRange<Float>, x: Float,
		front: Float, rear: Float, side: Float, corner: Float
	) -> Model {
		let l = length / 2, w = width / 2
		let rim = [
			at(x - l + corner, -w, z.lowerBound), at(x + l - corner, -w, z.lowerBound),
			at(x + l, -w + corner, z.lowerBound), at(x + l, w - corner, z.lowerBound),
			at(x + l - corner, w, z.lowerBound), at(x - l + corner, w, z.lowerBound),
			at(x - l, w - corner, z.lowerBound), at(x - l, -w + corner, z.lowerBound),
		]
		return Model([
			tankPlate(length: length, width: width, z: z, x: x,
				front: front, rear: rear, side: side, corner: corner, tone: Tone.turret),
		], lines: rim.indices.map {
			// The shadow at the turret's lower lip separates it from the hull deck.
			Line(from: rim[$0], to: rim[($0 + 1) % rim.count], tone: 70)
		})
	}

	/// Sloping armour with clipped plan-view corners, rather than stacked rectangular blocks.
	static func tankPlate(
		length: Float, width: Float, z: ClosedRange<Float>, x: Float = 0, y: Float = 0,
		front: Float, rear: Float, side: Float, corner: Float, tone: UInt8 = Tone.body
	) -> Solid {
		GFX.armour(length: length, width: width, z: z, x: x, y: y,
			front: front, rear: rear, side: side, corner: corner, tone: tone)
	}

	static func tankChassis(length: Float, width: Float, wheels: Int, deck: Float) -> Model {
		let trackWidth: Float = 2.8
		let trackY = (width - trackWidth) / 2
		let radius: Float = wheels == 4 ? 2.2 : (wheels <= 6 ? 1.85 : 1.65)
		let span = length - 5
		var solids = sides(trackY) { y in
			var track = GFX.box(length: length, width: trackWidth, z: 0 ... 5, y: y, tone: 36)
			for sign: Float in [-1, 1] {
				track.planes += [
					Plane(normal: V3(sign, 0, -1), through: at(sign * length / 2, y, 1.2)),
					Plane(normal: V3(sign, 0, 1), through: at(sign * length / 2, y, 3.8)),
				]
			}
			return track
		}
		for sign: Float in [-1, 1] {
			for index in 0 ..< wheels {
				let x: Float = wheels == 5 ? [-9, -4, 0, 4, 8][index] : -span / 2 + span * Float(index) / Float(wheels - 1)
				let y = sign * (width / 2 - 0.1)
				// A dark rubber rim separates each wheel from its neighbours and the metal hub.
				solids.append(tankCylinder(at: at(x, y, 2.5), radius: radius, length: 0.8,
					axis: .y, tone: 44))
				solids.append(tankCylinder(at: at(x, y + sign * 0.4, 2.5), radius: radius - 0.45, length: 0.2,
					axis: .y, tone: 110))
				solids.append(tankCylinder(at: at(x, y + sign * 0.55, 2.5), radius: 0.5, length: 0.2,
					axis: .y, tone: Tone.barrel))
			}
			// The fender catches the light above the dark track, leaving the wheel faces exposed.
			solids.append(tankPlate(length: length - 1, width: trackWidth + 0.3,
				z: 5 ... 5.6, y: sign * trackY,
				front: 0.6, rear: 0.6, side: 0, corner: 0.5, tone: Tone.body))
			solids.append(GFX.box(length: 6, width: 1.2, z: 5.6 ... deck + 0.2,
				x: -7, y: sign * (width / 2 - 1.3), tone: Tone.turret))
		}
		solids += [
			GFX.box(length: 4.5, width: 7, z: deck ... deck + 0.2, x: -8.3, tone: Tone.glass),
			tankPlate(length: 2.8, width: 2.4, z: deck ... deck + 0.4, x: 6, y: -2,
				front: 0.2, rear: 0.2, side: 0.2, corner: 0.4, tone: Tone.turret),
		]
		return Model(solids, lines: [-9.5, -8, -6.5].map {
			Line(from: at($0, -3, deck + 0.25), to: at($0, 3, deck + 0.25), tone: 90)
		})
	}

	static func tankCylinder(at center: V3, radius: Float, length: Float, axis: PartAxis, tone: UInt8) -> Solid {
		cylinder(at: center, radius: radius, length: length, axis: axis, tone: tone)
	}

	static func tankGun(from x: Float, length: Float, z: Float, caliber: Float) -> Model {
		Model([
			tankCylinder(at: at(x + length / 2, 0, z), radius: caliber / 2,
				length: length, axis: .x, tone: Tone.barrel),
			tankCylinder(at: at(x + 2, 0, z), radius: caliber * 0.7,
				length: 4, axis: .x, tone: Tone.turret),
		], lines: [
			// A one-pixel highlight keeps the tube legible after the silhouette pass.
			Line(from: at(x + 4, 0, z + caliber / 2), to: at(x + length - 0.8, 0, z + caliber / 2), tone: Tone.barrel),
		])
	}

	static func tankRoof(x: Float, z: Float) -> Model {
		Model([
			tankCylinder(at: at(x, 2.2, z + 0.5), radius: 1.3, length: 1, axis: .z, tone: Tone.turret),
			tankCylinder(at: at(x + 1.5, -2, z + 0.2), radius: 1.1, length: 0.4, axis: .z, tone: Tone.cargo),
			GFX.box(length: 1.2, width: 1.5, z: z + 0.7 ... z + 1.2, x: x + 0.3, y: 2.2, tone: Tone.glass),
		], lines: [
			Line(from: at(x - 2, 3, z - 0.5), to: at(x - 2.5, 3, z + 2.6), tone: Tone.antenna),
		])
	}

	static func tankSkirts(length: Float, width: Float, z: ClosedRange<Float>) -> Model {
		Model(sides(width / 2) {
			tankPlate(length: length, width: 0.6, z: z, x: -0.5, y: $0,
				front: 1, rear: 0.5, side: 0, corner: 0.2, tone: Tone.turret)
		}, lines: sides(width / 2 + 0.35) { y in
			stride(from: -length / 2 + 3, to: length / 2 - 1, by: 3.5).map { x in
				Line(from: at(x, y, z.lowerBound + 0.3), to: at(x, y, z.upperBound - 0.2), tone: 105)
			}
		}.flatMap { $0 })
	}
}
