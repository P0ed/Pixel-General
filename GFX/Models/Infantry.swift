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
			box(length: 1.2, width: 1.5, z: 12 ... 14, x: -1, y: 3, tone: Tone.pack),
			box(length: 0.8, width: 3.6, z: 16.7 ... 17.7, x: 2, tone: Tone.visor),
		], lines: [
			Line(from: at(-1, 3, 14), to: at(-1.7, 3, 19.5), tone: Tone.weapon),
		])
	}

	/// Combat engineer: rifle, bulky tool pack and a shovel strapped to its side.
	public static var engineer: Model {
		figure() + backpack(length: 3.6, width: 5.8) + rifle(compact: true) + Model([
			box(length: 1.8, width: 2.2, z: 7.5 ... 10, x: -2, y: 3.6, tone: Tone.pack),
			armour(length: 1.4, width: 4.8, z: 17 ... 20.2, x: -3, y: 3.8,
				front: 0.2, rear: 0.2, side: 0.5, corner: 0.7, tone: 145),
		], lines: [
			Line(from: at(-3, 3.8, 7.5), to: at(-3, 3.8, 18), tone: Tone.weapon),
			Line(from: at(-3, 2.7, 8), to: at(-3, 4.9, 8), tone: Tone.weapon),
		])
	}

	/// A grounded drone pilot with opaque FPV goggles and a two-grip controller.
	public static var fpv: Model {
		figure() + backpack(length: 2.2, width: 4.4) + arms(
			left: at(4.5, -2.5, 11.5), right: at(4.5, 2.5, 11.5)
		) + Model([
			// The visor projects ahead of the face; the strap wraps around the head.
			box(length: 2.3, width: 5.2, z: 16.4 ... 18.6, x: 2.8, tone: Tone.visor),
			box(length: 4.3, width: 4.5, z: 17 ... 17.6, tone: Tone.weapon),
			armour(length: 2.8, width: 6, z: 10.5 ... 12.3, x: 5.3,
				front: 0.3, rear: 0.2, side: 0.3, corner: 0.7, tone: Tone.weapon),
			box(length: 2, width: 1.3, z: 9.5 ... 11.5, x: 4.6, y: -2.5, tone: Tone.weapon),
			box(length: 2, width: 1.3, z: 9.5 ... 11.5, x: 4.6, y: 2.5, tone: Tone.weapon),
		], lines: [
			// Twin thumb sticks and the goggles' short antenna.
			Line(from: at(5.2, -1.5, 12.3), to: at(5.2, -1.5, 13), tone: 180),
			Line(from: at(5.2, 1.5, 12.3), to: at(5.2, 1.5, 13), tone: 180),
			Line(from: at(2.8, 2.5, 18.5), to: at(3.3, 2.5, 20.7), tone: Tone.weapon),
		])
	}
}

private extension Infantry {

	static func figure(helmet: UInt8 = Tone.helmet) -> Model {
		var solids: [Solid] = []
		for (x, y): (Float, Float) in [(0.8, -1.7), (-0.8, 1.7)] {
			solids += [
				armour(length: 4, width: 2.4, z: 0 ... 1.7, x: x + 0.8, y: y,
					front: 0.4, side: 0.3, corner: 0.4, tone: Tone.boots),
				limb(from: at(x, y, 1.5), to: at(x + 0.3, y, 5), radius: 1.1, tone: Tone.fatigues),
				limb(from: at(x + 0.3, y, 5), to: at(0, y, 9.5), radius: 1.25, tone: Tone.fatigues),
				box(length: 0.7, width: 1.7, z: 4.4 ... 6, x: x + 1.3, y: y, tone: Tone.webbing),
			]
		}
		solids += [
			box(length: 3.5, width: 5, z: 8.5 ... 10, tone: Tone.webbing),
			armour(length: 4.2, width: 5.5, z: 9.5 ... 15.2,
				front: 0.4, rear: 0.2, side: 0.5, corner: 0.6, tone: Tone.fatigues),
			box(length: 0.9, width: 4.3, z: 10.5 ... 14, x: 2, tone: Tone.webbing),
			box(length: 1.4, width: 1.6, z: 10 ... 11.8, x: 2.4, y: -1.2, tone: Tone.pack),
			box(length: 1.4, width: 1.6, z: 10 ... 11.8, x: 2.4, y: 1.2, tone: Tone.pack),
			cylinder(at: at(0.6, 0, 16.7), radius: 1.6, length: 3.2, axis: .z, tone: Tone.skin),
			cylinder(at: at(0.1, 0, 18), radius: 2.3, length: 0.9, axis: .z, tone: helmet),
			armour(length: 4.4, width: 4.5, z: 18.1 ... 20, x: 0.1,
				front: 0.9, rear: 0.7, side: 0.7, corner: 0.7, tone: helmet),
		]
		return Model(solids, lines: [
			Line(from: at(2.3, -1.5, 15.9), to: at(2.3, 1.5, 15.9), tone: Tone.webbing),
		])
	}

	static func backpack(length: Float = 2.8, width: Float = 4.8) -> Model {
		Model(armour(length: length, width: width, z: 9 ... 14.5, x: -3,
			front: 0.3, rear: 0.5, side: 0.4, corner: 0.5, tone: Tone.pack))
	}

	static func arms(left: V3, right: V3) -> Model {
		let hands = [left, right]
		var solids: [Solid] = []
		for (index, y): (Int, Float) in [-3.0, 3.0].enumerated() {
			let elbow = at(1.2, y, 11.1)
			solids += [
				limb(from: at(0, y * 0.85, 14.2), to: elbow, radius: 1.1, tone: Tone.fatigues),
				limb(from: elbow, to: hands[index], radius: 0.9, tone: Tone.fatigues),
				cylinder(at: hands[index], radius: 0.9, length: 1.5, axis: .z, tone: Tone.skin),
			]
		}
		return Model(solids)
	}

	static func rifle(compact: Bool = false) -> Model {
		let muzzle: Float = compact ? 10.5 : 12
		return arms(left: at(4.8, 2.4, 12), right: at(1.8, 2.8, 11.7)) + Model([
			box(length: 2.8, width: 1.1, z: 12 ... 13.2, x: -0.2, y: 2.8, tone: Tone.weapon),
			box(length: 3, width: 1.4, z: 12 ... 13.5, x: 2.3, y: 2.8, tone: Tone.weapon),
			box(length: 3.4, width: 1.2, z: 12.3 ... 13.2, x: 5.2, y: 2.8, tone: Tone.weapon),
			wedge(length: 1.4, width: 1.1, z: 9.7 ... 11.8, x: 2.7, y: 2.8, rising: .xPlus, tone: Tone.weapon),
			box(length: 1.8, width: 0.8, z: 13.5 ... 14.1, x: 2.6, y: 2.8, tone: Tone.weapon),
			barrel(from: at(6.5, 2.8, 12.9), to: at(muzzle, 2.8, 12.9),
				caliber: compact ? 1.2 : 0.7, tone: Tone.weapon),
		], lines: [
			Line(from: at(0, 3.4, 13.2), to: at(5.5, 3.4, 13.2), tone: 110),
			Line(from: at(muzzle - 0.3, 2.8, 12.9), to: at(muzzle - 0.3, 2.8, 13.8), tone: Tone.weapon),
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
