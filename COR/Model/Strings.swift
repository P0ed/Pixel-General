extension XY: CustomStringConvertible {
	public var description: String { "[\(x), \(y)]" }
}

public extension Unit {

	func status(cargo: Bool = false) -> String {
		.make { s in
			if self[.leadership] { s += "[LDR]" }
			if self[.recon] { s += "[RCN]" }
			if self[.crit] { s += "[CRT]" }
			if self[.evasion] { s += "[EVA]" }
			if self[.regen] { s += "[REG]" }
			if self[.mountaineer] { s += "[MTN]" }
			if self[.mhtn] { s += "[MHT]" }
			if self[.diag] { s += "[DIA]" }
			if kills != 0 { s += "[\(kills)]" }
			if !s.isEmpty { s += "\n" }

			s += .padding(8, [
				"SA: \(softAtk)",
				"HA: \(hardAtk)",
				"AA: \(airAtk)",
				"NA: \(navAtk)",
				"GD: \(groundDef)",
				"AD: \(airDef)",
				"INI: \(ini)",
				"MOV: \(mov)",
				"RNG: \(rng)",
			])
			s += "\n"
			s += .padding(24, [
				"\(self[.aux] ? "☆" : "★") \(typeDescription) \(cargo ? "⏺" : "")",
				.padding(16, [
					.padding(5, [
						 canMove ? "MOV" : "",
						 canAttack ? (ammo > 0 ? "ATK" : "LOW") : ""
					]),
					"LVL: \(lvl).\(subLvl)  AMMO: \(ammo)  ENT: \(entDef)",
				]),
			])
		}
	}

	private var skillsString: String {
		.make { s in

		}
	}
}

public extension String {

	mutating func pad(to length: Int) {
		let dlen = length - count
		if dlen > 0 {
			self += .init(repeating: " ", count: dlen)
		}
	}

	static func padding<let cnt: Int>(_ pad: Int, _ strings: [cnt of String]) -> String {
		.make { str in
			var padding = 0

			strings.forEach { s in
				str += s
				padding += pad
				str.pad(to: padding)
			}
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
		case .fpv: "FPV"

		// Artillery
		case .art105: "105mm"
		case .art155: "155mm"
		case .sp105: "Akatsiya"
		case .m777: "M777"
		case .m109: "M109A7"
		case .m147: "M147"
		case .mars: "MARS"
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
		case .strf90: "Strf 90 IV"
		case .strf90v: "Strf 90 V"
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

		// Naval
		case .cargo: "Transport"
		case .destroyer: "Destroyer"
		case .cruiser: "Cruiser"
		}
	}
}

extension Terrain: CustomStringConvertible {

	public var description: String {
		switch self {
		case .sea: "sea"
		case .river: "river"
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
