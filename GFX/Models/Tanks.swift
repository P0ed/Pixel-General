public extension Units {

	/// Leopard 1: cast turret, exposed suspension and a narrow gun mantlet.
	static var leo1: Model {
		tankChassis(length: 37.5, width: 21, wheels: 7, deck: 9.3)
		+ Model([
			tankPlate(length: 36, width: 18.75, z: 6.15 ... 9.3,
				front: 6.75, rear: 1.5, side: 0.9, corner: 1.5),
			tankPlate(length: 4.5, width: 5.25, z: 10.8 ... 13.8, x: 6,
				front: 1.05, rear: 0, side: 0.6, corner: 0.75, tone: Tone.turret),
		])
		+ tankTurret(length: 15.75, width: 15.75, z: 9.6 ... 14.4, x: -1.2,
			front: 3, rear: 2.25, side: 1.8, corner: 3.3)
		+ tankGun(from: 6.75, length: 23.25, z: 12.45, caliber: 2.1)
		+ tankRoof(x: -2.25, z: 14.4)
	}

	/// Abrams: long angular bustle, broad armour cheeks and seven road wheels behind skirts.
	static var m1A1: Model {
		tankChassis(length: 39, width: 22.5, wheels: 7, deck: 9.75)
		+ Model([
			tankPlate(length: 37.5, width: 20.25, z: 6.15 ... 9.75,
				front: 7.5, rear: 1.5, side: 0.75, corner: 1.5),
			tankPlate(length: 4.5, width: 5.25, z: 11.25 ... 14.85, x: 6.75,
				front: 0.75, rear: 0, side: 0.45, corner: 0.75, tone: Tone.turret),
		])
		+ tankTurret(length: 21, width: 17.25, z: 10.05 ... 15.9, x: -1.8,
			front: 3.6, rear: 1.2, side: 1.2, corner: 3.6)
		+ tankSkirts(length: 34.5, width: 22.5, z: 4.8 ... 8.7)
		+ tankGun(from: 7.5, length: 22.5, z: 13.35, caliber: 2.4)
		+ tankRoof(x: -2.25, z: 15.9)
	}

	/// T-72: six large road wheels, low glacis and a squat, faceted cast turret.
	static var t72: Model {
		tankChassis(length: 36, width: 21, wheels: 6, deck: 8.4)
		+ Model([
			tankPlate(length: 34.5, width: 18.75, z: 5.7 ... 8.4,
				front: 6.75, rear: 1.2, side: 1.05, corner: 1.8),
			tankPlate(length: 3.75, width: 4.5, z: 9.3 ... 12.6, x: 5.4,
				front: 0.75, rear: 0, side: 0.45, corner: 0.75, tone: Tone.turret),
		])
		+ tankTurret(length: 15, width: 16.5, z: 8.7 ... 13.05, x: -0.6,
			front: 3.3, rear: 2.4, side: 2.4, corner: 3.75)
		+ tankGun(from: 6, length: 24.75, z: 11.1, caliber: 2.1)
		+ tankRoof(x: -2.7, z: 13.05)
	}

	/// Leopard 2: long hull, a wide turret bustle and pointed, sloping frontal armour.
	static var leo2a6: Model {
		tankChassis(length: 39, width: 22.5, wheels: 7, deck: 9.9)
		+ Model([
			tankPlate(length: 37.5, width: 21, z: 6.15 ... 9.9,
				front: 7.5, rear: 1.5, side: 0.75, corner: 1.5),
			tankPlate(length: 4.5, width: 4.8, z: 11.25 ... 14.7, x: 7.5,
				front: 0.75, rear: 0, side: 0.45, corner: 0.75, tone: Tone.turret),
		] + sides(5.4) {
			tankPlate(length: 7.5, width: 6, z: 10.5 ... 15.45, x: 7.8, y: $0,
				front: 4.8, rear: 0, side: 0.45, corner: 1.05, tone: Tone.turret)
		})
		+ tankTurret(length: 18.75, width: 17.25, z: 10.2 ... 15.45, x: -1.2,
			front: 1.2, rear: 1.2, side: 0.75, corner: 2.7)
		+ tankSkirts(length: 34.5, width: 22.5, z: 4.5 ... 8.85)
		+ tankGun(from: 8.25, length: 24, z: 13.35, caliber: 2.4)
		+ tankRoof(x: -2.7, z: 15.45)
	}

	/// The T-72 chassis with reactive armour cheeks, a rear bustle and a raised sight.
	static var t90m: Model {
		t72 + Model([
			tankPlate(length: 6.75, width: 13.5, z: 9 ... 12.6, x: -9.3,
				front: 0, rear: 0.9, side: 0.6, corner: 1.2, tone: Tone.turret),
			GFX.box(length: 3.3, width: 3, z: 13.05 ... 15.45, x: 0, y: -3.9, tone: Tone.glass),
		] + sides(5.55) {
			tankPlate(length: 6.75, width: 4.8, z: 9.15 ... 13.2, x: 3.75, y: $0,
				front: 2.55, rear: 0.3, side: 0.6, corner: 1.2, tone: Tone.cargo)
		}) + tankSkirts(length: 31.5, width: 21, z: 4.2 ... 7.35)
	}

	/// Abrams with a visible bustle rack and an independent commander's thermal sight.
	static var m1A2: Model {
		m1A1 + Model([
			tankPlate(length: 5.25, width: 15.75, z: 11.25 ... 14.55, x: -13.95,
				front: 0, rear: 0, side: 0, corner: 1.05, tone: Tone.running),
			GFX.box(length: 3.6, width: 3.6, z: 15.9 ... 18.3, x: 0.9, y: -3.9, tone: Tone.glass),
		], lines: [-6, -3, 0, 3, 6].map {
			Line(from: at(-16.2, $0, 14.7), to: at(-12.45, $0, 14.7), tone: Tone.turret)
		})
	}

	/// Swedish Leopard with an armoured roof and reinforced frontal cheek modules.
	static var strv122: Model {
		leo2a6 + Model([
			tankPlate(length: 10.5, width: 10.5, z: 15.45 ... 16.5, x: -1.5,
				front: 0.45, rear: 0.45, side: 0.45, corner: 1.2, tone: Tone.cargo),
		] + sides(5.7) {
			tankPlate(length: 8.25, width: 6.3, z: 10.5 ... 15.9, x: 7.8, y: $0,
				front: 5.25, rear: 0, side: 0.45, corner: 1.2, tone: Tone.turret)
		}) + tankRoof(x: -2.7, z: 16.5)
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
		let trackWidth: Float = 4.2
		let trackY = (width - trackWidth) / 2
		let radius: Float = wheels == 4 ? 3.3 : (wheels <= 6 ? 2.775 : 2.475)
		let span = length - 7.5
		var solids = sides(trackY) { y in
			var track = GFX.box(length: length, width: trackWidth, z: 0 ... 7.5, y: y, tone: 36)
			for sign: Float in [-1, 1] {
				track.planes += [
					Plane(normal: V3(sign, 0, -1), through: at(sign * length / 2, y, 1.8)),
					Plane(normal: V3(sign, 0, 1), through: at(sign * length / 2, y, 5.7)),
				]
			}
			return track
		}
		for sign: Float in [-1, 1] {
			for index in 0 ..< wheels {
				let x: Float = wheels == 5 ? [-13.5, -6, 0, 6, 12][index] : -span / 2 + span * Float(index) / Float(wheels - 1)
				let y = sign * (width / 2 - 0.15)
				// A dark rubber rim separates each wheel from its neighbours and the metal hub.
				solids.append(tankCylinder(at: at(x, y, 3.75), radius: radius, length: 1.2,
					axis: .y, tone: 44))
				solids.append(tankCylinder(at: at(x, y + sign * 0.6, 3.75), radius: radius - 0.675, length: 0.3,
					axis: .y, tone: 110))
				solids.append(tankCylinder(at: at(x, y + sign * 0.825, 3.75), radius: 0.75, length: 0.3,
					axis: .y, tone: Tone.barrel))
			}
			// The fender catches the light above the dark track, leaving the wheel faces exposed.
			solids.append(tankPlate(length: length - 1.5, width: trackWidth + 0.45,
				z: 7.5 ... 8.4, y: sign * trackY,
				front: 0.9, rear: 0.9, side: 0, corner: 0.75, tone: Tone.body))
			solids.append(GFX.box(length: 9, width: 1.8, z: 8.4 ... deck + 0.3,
				x: -10.5, y: sign * (width / 2 - 1.95), tone: Tone.turret))
		}
		solids += [
			GFX.box(length: 6.75, width: 10.5, z: deck ... deck + 0.3, x: -12.45, tone: Tone.glass),
			tankPlate(length: 4.2, width: 3.6, z: deck ... deck + 0.6, x: 9, y: -3,
				front: 0.3, rear: 0.3, side: 0.3, corner: 0.6, tone: Tone.turret),
		]
		return Model(solids, lines: [-14.25, -12, -9.75].map {
			Line(from: at($0, -4.5, deck + 0.375), to: at($0, 4.5, deck + 0.375), tone: 90)
		})
	}

	static func tankCylinder(at center: V3, radius: Float, length: Float, axis: PartAxis, tone: UInt8) -> Solid {
		cylinder(at: center, radius: radius, length: length, axis: axis, tone: tone)
	}

	static func tankGun(from x: Float, length: Float, z: Float, caliber: Float) -> Model {
		Model([
			tankCylinder(at: at(x + length / 2, 0, z), radius: caliber / 2,
				length: length, axis: .x, tone: Tone.barrel),
			tankCylinder(at: at(x + 3, 0, z), radius: caliber * 0.7,
				length: 6, axis: .x, tone: Tone.turret),
		], lines: [
			// A one-pixel highlight keeps the tube legible after the silhouette pass.
			Line(from: at(x + 6, 0, z + caliber / 2), to: at(x + length - 1.2, 0, z + caliber / 2), tone: Tone.barrel),
		])
	}

	static func tankRoof(x: Float, z: Float) -> Model {
		Model([
			tankCylinder(at: at(x, 3.3, z + 0.75), radius: 1.95, length: 1.5, axis: .z, tone: Tone.turret),
			tankCylinder(at: at(x + 2.25, -3, z + 0.3), radius: 1.65, length: 0.6, axis: .z, tone: Tone.cargo),
			GFX.box(length: 1.8, width: 2.25, z: z + 1.05 ... z + 1.8, x: x + 0.45, y: 3.3, tone: Tone.glass),
		], lines: [
			Line(from: at(x - 3, 4.5, z - 0.75), to: at(x - 3.75, 4.5, z + 3.9), tone: Tone.antenna),
		])
	}

	static func tankSkirts(length: Float, width: Float, z: ClosedRange<Float>) -> Model {
		Model(sides(width / 2) {
			tankPlate(length: length, width: 0.9, z: z, x: -0.75, y: $0,
				front: 1.5, rear: 0.75, side: 0, corner: 0.3, tone: Tone.turret)
		}, lines: sides(width / 2 + 0.525) { y in
			stride(from: -length / 2 + 4.5, to: length / 2 - 1.5, by: 5.25).map { x in
				Line(from: at(x, y, z.lowerBound + 0.45), to: at(x, y, z.upperBound - 0.3), tone: 105)
			}
		}.flatMap { $0 })
	}
}
