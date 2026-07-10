extension XY: CustomStringConvertible {
	public var description: String { "[\(x), \(y)]" }
}

public extension Unit {

	func status(cargo: Bool = false) -> String {
		.make { status in
			status += "\(self[.aux] ? "☆" : "★") \(typeDescription) \(cargo ? "⏺" : "")"
			status.pad(to: 15)
			status += "\(apString)  "
			status += .makeStatus(pad: 7) { add in
				add("AM: \(ammo)")
				add("SA: \(softAtk)")
				add("HA: \(hardAtk)")
				add("AA: \(airAtk)")
				add("GD: \(groundDef)")
				add("AD: \(airDef)")
				add("IN: \(ini)")
				add("MV: \(mov)")
				add("EN: \(entDef)")
			}
			status += skillsString
		}
	}

	private var skillsString: String {
		("XP: \(xpString)  ")
		+ (self[.leadership] ? "[LR]" : "")
		+ (self[.recon] ? "[RC]" : "")
		+ (self[.crit] ? "[CR]" : "")
		+ (self[.evasion] ? "[EV]" : "")
		+ (self[.regen] ? "[RG]" : "")
		+ (self[.mountaineer] ? "[MT]" : "")
		+ (self[.mhtn] ? "[MH]" : "")
		+ (self[.diag] ? "[DI]" : "")
		+ (kills != 0 ? "[\(kills)]" : "")
	}

	private var apString: String { "[\(canMove ? "M" : " ")|\(canAttack ? (ammo > 0 ? "A" : "L") : " ")]" }
	private var xpString: String { "\(lvl).\(subLvl)" }
}

public extension String {

	mutating func pad(to length: Int) {
		let dlen = length - count
		if dlen > 0 {
			self += .init(repeating: " ", count: dlen)
		}
	}

	static func makeStatus(pad: Int = 12, _ mk: ((String) -> Void) -> Void) -> String {
		.make { str in
			var padding = 0

			func add(_ s: String) {
				str += s
				padding += pad
				str.pad(to: padding)
			}

			mk(add)
		}
	}
}

public extension Unit {

	var typeDescription: String {
		switch model {
		case .none: ""
		case .truck: "Truck"

		// Infantry
		case .militia: "Militia"
		case .regular: "Infantry"
		case .ranger: "Rangers"
		case .engineer: "Engineer"
		case .ksk: "KSK"
		case .delta: "Delta Force"
		case .speznas: "Speznas"

		// Artillery
		case .art105: "105mm"
		case .art155: "155mm"
		case .sp105: "Akatsiya"
		case .m777: "M777"
		case .m270: "M270"
		case .pzh: "PzH 2000"

		// Anti-air
		case .bofors: "40mm L/70"
		case .nasams: "NASAMS"
		case .patriot: "Patriot"
		case .neva: "Neva"
		case .s300: "S300"
		case .lvkv90: "Lvkv 90"
		case .tunguska: "Tunguska"

		// IFV / recon
		case .fennek: "Fennek"
		case .boxer: "Boxer"
		case .brdm2: "BRDM"
		case .m113: "M113"
		case .m2A2: "M2A2"
		case .strf90: "Strf 90"
		case .strf90v: "Strf 90 mkV"
		case .kf41: "KF41"
		case .cv9035: "CV9035"
		case .bmp: "BMP"

		// Tanks
		case .m48: "M48"
		case .m1A1: "M1A1"
		case .m1A2: "M1A2"
		case .leo1: "Leopard 1A5"
		case .strv103: "Strv 103"
		case .strv122: "Strv 122"
		case .kf51: "KF51"
		case .leo2a6: "Leopard 2A6"
		case .t55: "T-55BVM"
		case .t72: "T-72B"
		case .t90m: "T-90M"

		// Air
		case .skeldar: "Skeldar"
		case .skeldarm: "Skeldar M"
		case .nh90: "NH90"
		case .mh6: "MH6"
		case .mq9: "MQ9"
		case .mi8: "Mi-8"
		case .mi24: "Mi-24"
		case .orlan: "Orlan-10"
		case .gripen: "Gripen"
		case .f16: "F16"
		case .f35: "F35"
		case .mig29: "Mig-29"
		case .su57: "Su-57"
		case .su25: "Su-25"
		case .su27: "Su-27"
		}
	}
}

extension Terrain: CustomStringConvertible {

	public var description: String {
		switch self {
		case .water: "water"
		case .bridgeWE, .bridgeSN: "bridge"
		case .field: "field"
		case .forest: "forest"
		case .hill, .forestHill: "hill"
		case .mountain: "mountain"
		case .city: "city"
		case .airfield: "airfield"
		case .villageE, .villageN, .villageW, .villageS: "village"
		case .fort: "fort"
		case _ where isRoad: "road"
		default: ""
		}
	}
}
