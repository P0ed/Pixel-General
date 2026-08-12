/// Foot units, authored facing `+x`. A figure this small is mostly silhouette, so the
/// weapon, antenna and rotor arms are strokes rather than blocks that would fatten it.
public enum Infantry {

	public enum Tone {
		public static let fatigues: UInt8 = 210
		public static let webbing: UInt8 = 175
		public static let helmet: UInt8 = 190
		public static let pack: UInt8 = 160
		public static let weapon: UInt8 = 64
		public static let visor: UInt8 = 120
	}

	public static var rifleman: Model {
		Model(figure(helmet: Tone.helmet) + [
			box(length: 2.5, width: 5, z: 8 ... 12.5, x: -2.5, tone: Tone.pack),
		], lines: [
			Line(from: at(-1.5, -1.5, 11), to: at(6, -3, 8.5), tone: Tone.weapon),
		])
	}

	/// Special forces: no pack, a stubbier weapon held high, antenna off the shoulder.
	public static var special: Model {
		Model(figure(helmet: Tone.visor) + [
			box(length: 2.5, width: 6, z: 8.5 ... 12, x: -1, tone: Tone.webbing),
		], lines: [
			Line(from: at(-0.5, -1.5, 11.5), to: at(5.5, -2.5, 10.5), tone: Tone.weapon),
			Line(from: at(-2, 2, 12.5), to: at(-3.5, 3, 17), tone: Tone.weapon),
		])
	}

	/// First-person-view quadcopter: a hovering body with four stroked rotor discs.
	public static var quad: Model {
		let deck: Float = 8
		var solids = [box(length: 4, width: 4, z: deck ... deck + 2.5, tone: Tone.webbing)]
		solids += arms.map { arm in
			box(length: 1.2, width: 1.2, z: deck + 2.5 ... deck + 3.2, x: arm.x, y: arm.y, tone: Tone.pack)
		}

		var lines: [Line] = arms.flatMap { arm -> [Line] in
			[
				Line(from: at(0, 0, deck + 1.5), to: at(arm.x, arm.y, deck + 2.8), tone: Tone.weapon),
				Line(
					from: at(arm.x - 2.5, arm.y, deck + 3.4),
					to: at(arm.x + 2.5, arm.y, deck + 3.4),
					tone: Tone.weapon
				),
				Line(
					from: at(arm.x, arm.y - 2.5, deck + 3.4),
					to: at(arm.x, arm.y + 2.5, deck + 3.4),
					tone: Tone.weapon
				),
			]
		}
		lines.append(Line(from: at(2, 0, deck + 1), to: at(4.5, 0, deck), tone: Tone.visor))

		return Model(solids, lines: lines)
	}

	private static let arms: [(x: Float, y: Float)] = [(5, -5), (5, 5), (-5, -5), (-5, 5)]
}

private extension Infantry {

	/// Legs, torso and head: the part every foot sprite shares.
	static func figure(helmet: UInt8) -> [Solid] {
		sides(1.7) { box(length: 2.5, width: 2.4, z: 0 ... 8, y: $0, tone: Tone.fatigues) }
		+ [
			box(length: 3.5, width: 6, z: 8 ... 13.5, tone: Tone.fatigues),
			box(length: 2.5, width: 2.5, z: 13.5 ... 15, tone: Tone.fatigues),
			box(length: 4, width: 4, z: 14.5 ... 16.5, tone: helmet),
		]
	}
}
