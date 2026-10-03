/// Unit shapes, authored nose-first along `+x` (screen right-and-down).
public enum Units {

	public enum Shape: UInt8, Sendable, CaseIterable {
		case tank, heavyTank, lowTank, leo2
		case recon, fennek, brdm2, carrier, ifv
		case truck, launcher
		case artillery, gun
		case spaa, flak
		case rifleman, special, quad
		case helicopter, scout, drone, jet, heavyJet
		case cargo, destroyer, cruiser
		case t90m, m1A2, strv122

		public var model: Model {
			switch self {
			case .tank: Units.tank
			case .heavyTank: Units.heavyTank
			case .lowTank: Units.lowTank
			case .leo2: Units.leo2
			case .t90m: Units.t90m
			case .m1A2: Units.m1A2
			case .strv122: Units.strv122
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
		public static let body: UInt8 = 200
		public static let turret: UInt8 = 180
		public static let barrel: UInt8 = 160
		public static let cargo: UInt8 = 190
		public static let glass: UInt8 = 140
		public static let running: UInt8 = 60
		public static let wheel: UInt8 = 90
		public static let antenna: UInt8 = 70
	}
}
