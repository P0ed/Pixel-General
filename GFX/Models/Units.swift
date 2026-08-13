/// Box-shaped ground units, authored nose-first along `+x` (screen right-and-down).
public enum Units {

	/// Every silhouette a unit can be drawn with, whatever it moves on.
	public enum Shape: UInt8, Sendable, CaseIterable {
		case tank, heavyTank, lowTank
		case recon, fennek, brdm2, carrier, ifv
		case truck, launcher
		case artillery, gun
		case spaa, flak
		case rifleman, special, quad
		case helicopter, scout, drone, jet, heavyJet
		case cargo, destroyer, cruiser

		public var model: Model {
			switch self {
			case .tank: Units.tank
			case .heavyTank: Units.heavyTank
			case .lowTank: Units.lowTank
			case .recon: Units.recon
			case .fennek: Units.fennek
			case .brdm2: Units.brdm2
			case .carrier: Units.carrier
			case .ifv: Units.ifv
			case .truck: Units.truck
			case .launcher: Units.launcher
			case .artillery: Units.artillery
			case .gun: Units.gun
			case .spaa: Units.spaa
			case .flak: Units.flak
			case .rifleman: Infantry.rifleman
			case .special: Infantry.special
			case .quad: Infantry.quad
			case .helicopter: Aircraft.helicopter
			case .scout: Aircraft.scout
			case .drone: Aircraft.drone
			case .jet: Aircraft.jet
			case .heavyJet: Aircraft.heavyJet
			case .cargo: Ships.cargo
			case .destroyer: Ships.destroyer
			case .cruiser: Ships.cruiser
			}
		}

		/// Airborne shapes hover clear of the tile; the rest stand on it.
		public var flies: Bool {
			switch self {
			case .quad, .helicopter, .scout, .drone, .jet, .heavyJet: true
			default: false
			}
		}
	}

	public enum Tone {
		public static let body: UInt8 = 215
		public static let turret: UInt8 = 195
		public static let barrel: UInt8 = 165
		public static let cargo: UInt8 = 205
		public static let glass: UInt8 = 145
		public static let running: UInt8 = 120
		public static let wheel: UInt8 = 95
		public static let antenna: UInt8 = 72
	}

	public static var tank: Model {
		Model([
			tracks(length: 24, width: 13),
			box(length: 21, width: 10, z: 3 ... 7, x: -1),
			wedge(length: 6, width: 10, z: 3.5 ... 7, x: 8.5, rising: .xMinus),
			box(length: 11, width: 9, z: 7 ... 11, x: -3, tone: Tone.turret),
			box(length: 15, width: 2, z: 8.5 ... 10.5, x: 8, tone: Tone.barrel),
		])
	}

	public static var heavyTank: Model {
		Model([
			tracks(length: 25, width: 14),
			box(length: 22, width: 11, z: 3 ... 7.5, x: -1),
			wedge(length: 7, width: 11, z: 3.5 ... 7.5, x: 8.5, rising: .xMinus),
			box(length: 12, width: 10, z: 7.5 ... 12, x: -3, tone: Tone.turret),
			box(length: 17, width: 2.5, z: 9.5 ... 11.5, x: 8.5, tone: Tone.barrel),
		])
	}

	/// Low-slung hull, small turret: the Strv / T-72 read.
	public static var lowTank: Model {
		Model([
			tracks(length: 23, width: 13),
			box(length: 20, width: 11, z: 3 ... 5.5, x: -1),
			wedge(length: 8, width: 11, z: 3 ... 5.5, x: 7.5, rising: .xMinus),
			box(length: 9, width: 8, z: 5.5 ... 8.5, x: -3, tone: Tone.turret),
			box(length: 16, width: 2, z: 6.5 ... 8, x: 8, tone: Tone.barrel),
		])
	}

	/// Tracked personnel carrier: a plain sloped box with a cupola.
	public static var recon: Model {
		Model([
			tracks(length: 19, width: 12),
			box(length: 16, width: 10, z: 3 ... 8.5, x: -1.5),
			wedge(length: 6, width: 10, z: 4.5 ... 8.5, x: 7.5, rising: .xMinus),
			box(length: 4, width: 4, z: 8.5 ... 10, x: -2, tone: Tone.turret),
		])
	}

	/// Light 4x4 scout: raked screen over a long bonnet, a remote gun on the cabin roof and
	/// the observation mast its optics ride on — whip aerials off the rear quarter.
	public static var fennek: Model {
		Model(wheels(at: [-7, 7]) + [
			box(length: 13, width: 10, z: 3 ... 9, x: -4.5),
			wedge(length: 3.5, width: 10, z: 6.5 ... 9, x: 3.75, rising: .xMinus, tone: Tone.glass),
			box(length: 4, width: 10, z: 3 ... 6.5, x: 4),
			wedge(length: 4.5, width: 10, z: 3 ... 6.5, x: 8.25, rising: .xMinus),
			box(length: 4, width: 4, z: 9 ... 10.8, x: -2, tone: Tone.turret),
			box(length: 2.5, width: 2.5, z: 9 ... 13.5, x: -7.5, tone: Tone.barrel),
			box(length: 3, width: 4.5, z: 13.5 ... 15.5, x: -7, tone: Tone.turret),
		], lines: [
			Line(from: at(-6, 4, 9), to: at(-8.5, 5.5, 15), tone: Tone.antenna),
			Line(from: at(-10, 4, 9), to: at(-12, 5.5, 14), tone: Tone.antenna),
		])
	}

	/// Amphibious 4x4 scout car: a long boat prow off a low hull, a small gun turret amidships
	/// and the belly wheels slung between the axles — the BRDM-2 read.
	public static var brdm2: Model {
		Model(wheels(at: [-7.5, 6.5]) + belly(at: [-2, 2]) + [
			box(length: 17, width: 10, z: 3 ... 8, x: -2.5),
			wedge(length: 6.5, width: 10, z: 3 ... 8, x: 9.25, rising: .xMinus),
			box(length: 5, width: 5, z: 8 ... 10.5, x: -2, tone: Tone.turret),
			box(length: 9, width: 1.5, z: 9 ... 10, x: 4.5, tone: Tone.barrel),
		])
	}

	/// Wheeled APC: sloped bow over a low hull, in the shape of `bxr.png`.
	public static var carrier: Model {
		Model(wheels(at: [-8, 0, 8]) + [
			box(length: 22, width: 10, z: 3 ... 8, x: -1),
			wedge(length: 7, width: 10, z: 4.5 ... 8, x: 8.5, rising: .xMinus),
			box(length: 7, width: 7, z: 8 ... 11, x: -4, tone: Tone.turret),
			box(length: 9, width: 2, z: 9 ... 10.5, x: 3, tone: Tone.barrel),
		])
	}

	/// Tracked IFV: taller hull, autocannon turret set back.
	public static var ifv: Model {
		Model([
			tracks(length: 21, width: 12),
			box(length: 18, width: 10, z: 3 ... 7.5, x: -1.5),
			wedge(length: 7, width: 10, z: 4 ... 7.5, x: 8, rising: .xMinus),
			box(length: 8, width: 7, z: 7.5 ... 11, x: -3, tone: Tone.turret),
			box(length: 11, width: 1.5, z: 9 ... 10, x: 6, tone: Tone.barrel),
		])
	}

	public static var truck: Model {
		Model(wheels(at: [-8, -1.5, 7]) + [
			box(length: 25, width: 8, z: 2.5 ... 4.5, tone: Tone.running),
			box(length: 14, width: 11, z: 4.5 ... 11, x: -5, tone: Tone.cargo),
			box(length: 8, width: 10, z: 4.5 ... 8, x: 8),
			box(length: 6.5, width: 9, z: 8 ... 10, x: 7, tone: Tone.glass),
		])
	}

	/// Flat-bed launcher: raked cells over a truck chassis.
	public static var launcher: Model {
		Model(wheels(at: [-8, -1.5, 7]) + [
			box(length: 25, width: 8, z: 2.5 ... 4.5, tone: Tone.running),
			box(length: 8, width: 10, z: 4.5 ... 9, x: 8),
			wedge(length: 16, width: 10, z: 4.5 ... 12.5, x: -4.5, rising: .xMinus, tone: Tone.cargo),
		])
	}

	/// Tracked gun: long barrel over a boxy superstructure.
	public static var artillery: Model {
		Model([
			tracks(length: 22, width: 13),
			box(length: 19, width: 10, z: 3 ... 6, x: -1),
			box(length: 13, width: 9, z: 6 ... 10.5, x: -4, tone: Tone.turret),
			box(length: 19, width: 2, z: 9 ... 11, x: 7, tone: Tone.barrel),
		])
	}

	/// Towed howitzer: shield and barrel over splayed trails.
	public static var gun: Model {
		Model(wheels(at: [0]) + [
			wedge(length: 13, width: 5, z: 1 ... 3.5, x: -8, rising: .xPlus, tone: Tone.running),
			box(length: 7, width: 7, z: 3 ... 6, x: -2, tone: Tone.turret),
			box(length: 3, width: 11, z: 3 ... 8, x: 2, tone: Tone.body),
			box(length: 16, width: 2.5, z: 5 ... 7, x: 9, tone: Tone.barrel),
		])
	}

	/// Tracked anti-air: radar plate behind a turret with raised barrels.
	public static var spaa: Model {
		Model([
			tracks(length: 21, width: 13),
			box(length: 18, width: 10, z: 3 ... 6, x: -1),
			box(length: 9, width: 9, z: 6 ... 9.5, x: -2, tone: Tone.turret),
			box(length: 2, width: 7, z: 9.5 ... 13, x: -6, tone: Tone.cargo),
			box(length: 11, width: 1.5, z: 9 ... 10.5, x: 6, y: -2, tone: Tone.barrel),
			box(length: 11, width: 1.5, z: 9 ... 10.5, x: 6, y: 2, tone: Tone.barrel),
		])
	}

	/// Towed anti-air gun: a short mount with the barrel pointing up.
	public static var flak: Model {
		Model([
			box(length: 12, width: 12, z: 0 ... 2, tone: Tone.running),
			box(length: 8, width: 8, z: 2 ... 5.5, tone: Tone.turret),
			box(length: 3, width: 2, z: 5.5 ... 12, x: 1, y: -2.5, tone: Tone.barrel),
			box(length: 3, width: 2, z: 5.5 ... 12, x: 1, y: 2.5, tone: Tone.barrel),
		])
	}
}

private extension Units {

	static func box(
		length: Float,
		width: Float,
		z: ClosedRange<Float>,
		x: Float = 0,
		y: Float = 0,
		tone: UInt8 = Tone.body
	) -> Solid {
		GFX.box(length: length, width: width, z: z, x: x, y: y, tone: tone)
	}

	static func wedge(
		length: Float,
		width: Float,
		z: ClosedRange<Float>,
		x: Float = 0,
		y: Float = 0,
		rising: Direction,
		tone: UInt8 = Tone.body
	) -> Solid {
		GFX.wedge(length: length, width: width, z: z, x: x, y: y, rising: rising, tone: tone)
	}

	static func tracks(length: Float, width: Float) -> Solid {
		box(length: length, width: width, z: 0 ... 3, tone: Tone.running)
	}

	static func wheels(at positions: [Float]) -> [Solid] {
		positions.map { box(length: 4, width: 12, z: 0 ... 3, x: $0, tone: Tone.wheel) }
	}

	/// Small chain-driven wheels hung inboard, under the hull rather than beside it.
	static func belly(at positions: [Float]) -> [Solid] {
		positions.map { box(length: 3, width: 9.5, z: 1 ... 3, x: $0, tone: Tone.wheel) }
	}
}
