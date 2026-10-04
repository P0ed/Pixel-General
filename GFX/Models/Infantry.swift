/// Foot units, authored facing `+x`. Equipment and bent limbs keep each role
/// readable at the game's native pixel size.
public enum Infantry {

	public enum Tone {
		public static let fatigues: UInt8 = 210
		public static let webbing: UInt8 = 175
		public static let helmet: UInt8 = 190
		public static let pack: UInt8 = 160
		public static let weapon: UInt8 = 64
		public static let visor: UInt8 = 100
		public static let skin: UInt8 = 230
		public static let boots: UInt8 = 85
	}

	public static var rifleman: Model {
		figure() + backpack() + rifle()
	}

	/// Compact suppressed carbine, dark helmet, eye protection and shoulder radio.
	public static var special: Model {
		figure(helmet: Tone.visor) + rifle(compact: true) + Model([
			box(length: 1.8, width: 2.25, z: 18 ... 21, x: -1.5, y: 4.5, tone: Tone.pack),
			box(length: 1.2, width: 5.4, z: 25.05 ... 26.55, x: 3, tone: Tone.visor),
		], lines: [
			Line(from: at(-1.5, 4.5, 21), to: at(-2.55, 4.5, 29.25), tone: Tone.weapon),
		])
	}

	/// Combat engineer: rifle, bulky tool pack and a shovel strapped to its side.
	public static var engineer: Model {
		figure() + backpack(length: 5.4, width: 8.7) + rifle(compact: true) + Model([
			box(length: 2.7, width: 3.3, z: 11.25 ... 15, x: -3, y: 5.4, tone: Tone.pack),
			armour(length: 2.1, width: 7.2, z: 25.5 ... 30.3, x: -4.5, y: 5.7,
				front: 0.3, rear: 0.3, side: 0.75, corner: 1.05, tone: 145),
		], lines: [
			Line(from: at(-4.5, 5.7, 11.25), to: at(-4.5, 5.7, 27), tone: Tone.weapon),
			Line(from: at(-4.5, 4.05, 12), to: at(-4.5, 7.35, 12), tone: Tone.weapon),
		])
	}

	/// A grounded drone pilot with opaque FPV goggles and a two-grip controller.
	public static var fpv: Model {
		figure() + backpack(length: 3.3, width: 6.6) + arms(
			left: at(6.75, -3.75, 17.25), right: at(6.75, 3.75, 17.25)
		) + Model([
			// The visor projects ahead of the face; the strap wraps around the head.
			box(length: 3.45, width: 7.8, z: 24.6 ... 27.9, x: 4.2, tone: Tone.visor),
			box(length: 6.45, width: 6.75, z: 25.5 ... 26.4, tone: Tone.weapon),
			armour(length: 4.2, width: 9, z: 15.75 ... 18.45, x: 7.95,
				front: 0.45, rear: 0.3, side: 0.45, corner: 1.05, tone: Tone.weapon),
			box(length: 3, width: 1.95, z: 14.25 ... 17.25, x: 6.9, y: -3.75, tone: Tone.weapon),
			box(length: 3, width: 1.95, z: 14.25 ... 17.25, x: 6.9, y: 3.75, tone: Tone.weapon),
		], lines: [
			// Twin thumb sticks and the goggles' short antenna.
			Line(from: at(7.8, -2.25, 18.45), to: at(7.8, -2.25, 19.5), tone: 180),
			Line(from: at(7.8, 2.25, 18.45), to: at(7.8, 2.25, 19.5), tone: 180),
			Line(from: at(4.2, 3.75, 27.75), to: at(4.95, 3.75, 31.05), tone: Tone.weapon),
		])
	}
}

private extension Infantry {

	static func figure(helmet: UInt8 = Tone.helmet) -> Model {
		var solids: [Solid] = []
		for (x, y): (Float, Float) in [(1.2, -2.55), (-1.2, 2.55)] {
			solids += [
				armour(length: 6, width: 3.6, z: 0 ... 2.55, x: x + 1.2, y: y,
					front: 0.6, side: 0.45, corner: 0.6, tone: Tone.boots),
				limb(from: at(x, y, 2.25), to: at(x + 0.45, y, 7.5), radius: 1.65, tone: Tone.fatigues),
				limb(from: at(x + 0.45, y, 7.5), to: at(0, y, 14.25), radius: 1.875, tone: Tone.fatigues),
				box(length: 1.05, width: 2.55, z: 6.6 ... 9, x: x + 1.95, y: y, tone: Tone.webbing),
			]
		}
		solids += [
			box(length: 5.25, width: 7.5, z: 12.75 ... 15, tone: Tone.webbing),
			armour(length: 6.3, width: 8.25, z: 14.25 ... 22.8,
				front: 0.6, rear: 0.3, side: 0.75, corner: 0.9, tone: Tone.fatigues),
			box(length: 1.35, width: 6.45, z: 15.75 ... 21, x: 3, tone: Tone.webbing),
			box(length: 2.1, width: 2.4, z: 15 ... 17.7, x: 3.6, y: -1.8, tone: Tone.pack),
			box(length: 2.1, width: 2.4, z: 15 ... 17.7, x: 3.6, y: 1.8, tone: Tone.pack),
			cylinder(at: at(0.9, 0, 25.05), radius: 2.4, length: 4.8, axis: .z, tone: Tone.skin),
			cylinder(at: at(0.15, 0, 27), radius: 3.45, length: 1.35, axis: .z, tone: helmet),
			armour(length: 6.6, width: 6.75, z: 27.15 ... 30, x: 0.15,
				front: 1.35, rear: 1.05, side: 1.05, corner: 1.05, tone: helmet),
		]
		return Model(solids, lines: [
			Line(from: at(3.45, -2.25, 23.85), to: at(3.45, 2.25, 23.85), tone: Tone.webbing),
		])
	}

	static func backpack(length: Float = 4.2, width: Float = 7.2) -> Model {
		Model(armour(length: length, width: width, z: 13.5 ... 21.75, x: -4.5,
			front: 0.45, rear: 0.75, side: 0.6, corner: 0.75, tone: Tone.pack))
	}

	static func arms(left: V3, right: V3) -> Model {
		let hands = [left, right]
		var solids: [Solid] = []
		for (index, y): (Int, Float) in [-4.5, 4.5].enumerated() {
			let elbow = at(1.8, y, 16.65)
			solids += [
				limb(from: at(0, y * 0.85, 21.3), to: elbow, radius: 1.65, tone: Tone.fatigues),
				limb(from: elbow, to: hands[index], radius: 1.35, tone: Tone.fatigues),
				cylinder(at: hands[index], radius: 1.35, length: 2.25, axis: .z, tone: Tone.skin),
			]
		}
		return Model(solids)
	}

	static func rifle(compact: Bool = false) -> Model {
		let muzzle: Float = compact ? 15.75 : 18
		return arms(left: at(7.2, 3.6, 18), right: at(2.7, 4.2, 17.55)) + Model([
			box(length: 4.2, width: 1.65, z: 18 ... 19.8, x: -0.3, y: 4.2, tone: Tone.weapon),
			box(length: 4.5, width: 2.1, z: 18 ... 20.25, x: 3.45, y: 4.2, tone: Tone.weapon),
			box(length: 5.1, width: 1.8, z: 18.45 ... 19.8, x: 7.8, y: 4.2, tone: Tone.weapon),
			wedge(length: 2.1, width: 1.65, z: 14.55 ... 17.7, x: 4.05, y: 4.2, rising: .xPlus, tone: Tone.weapon),
			box(length: 2.7, width: 1.2, z: 20.25 ... 21.15, x: 3.9, y: 4.2, tone: Tone.weapon),
			barrel(from: at(9.75, 4.2, 19.35), to: at(muzzle, 4.2, 19.35),
				caliber: compact ? 1.8 : 1.05, tone: Tone.weapon),
		], lines: [
			Line(from: at(0, 5.1, 19.8), to: at(8.25, 5.1, 19.8), tone: 110),
			Line(from: at(muzzle - 0.45, 4.2, 19.35), to: at(muzzle - 0.45, 4.2, 20.7), tone: Tone.weapon),
		])
	}

	/// An eight-sided segment in any direction, for elbows and a staggered stance.
	static func limb(from start: V3, to end: V3, radius: Float, tone: UInt8) -> Solid {
		let axis = (end - start).normalized
		let across = V3(axis.z, 0, -axis.x).normalized
		let around = V3(axis.y * across.z, axis.z * across.x - axis.x * across.z, -axis.y * across.x)
		var planes = [Plane(normal: -axis, through: start), Plane(normal: axis, through: end)]
		for normal in [across, -across, around, -around] {
			planes.append(Plane(normal: normal, offset: normal.dot(start) + radius))
		}
		for a: Float in [-1, 1] {
			for b: Float in [-1, 1] {
				let normal = across * a + around * b
				planes.append(Plane(normal: normal, offset: normal.dot(start) + radius * 1.4142136))
			}
		}
		let margin = V3(abs(across.x) + abs(around.x), abs(across.y) + abs(around.y),
			abs(across.z) + abs(around.z)) * radius
		return Solid(planes: planes, from: start.min(end) - margin, to: start.max(end) + margin, tone: tone)
	}
}
