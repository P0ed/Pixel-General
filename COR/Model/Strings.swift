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
		switch type {
		case .supply: "Truck"
		case .inf:
			switch tier {
			case 0: "Militia"
			case 1: country == .usa ? "Rangers" : "Infantry"
			case 2: "Engineer"
			default:
				switch country.team {
				case .axis: "KSK"
				case .allies: "Delta Force"
				case .soviet: "Speznas"
				case .none: ""
				}
			}
		case .art:
			if tier == 0 {
				"105mm"
			} else {
				switch country.team {
				case .allies: "M777"
				default: "155mm"
				}
			}
		case .wheelArt:
			"Bohdana"
		case .trackArt:
			switch country.team {
			case .axis: "PzH 2000"
			case .allies: "M270"
			case .soviet: "2С3"
			case .none: ""
			}
		case .aa:
			switch country.team {
			case _ where tier == 0: "40mm L/70"
			case .axis: "NASAMS"
			case .allies: "Patriot"
			case .soviet: "S300"
			case .none: ""
			}
		case .wheelAA: 
			"Neva"
		case .trackAA:
			switch country.team {
			case .axis: "Lvkv 90"
			case .soviet: "Tunguska"
			case .allies: ""
			case .none: ""
			}
		case .lightWheel:
			switch country.team {
			case .axis, .allies: tier == 0 ? "Fennek" : "Boxer"
			case .soviet: "BRDM"
			case .none: ""
			}
		case .lightTrack:
			switch country.team {
			case .axis: country == .ger ? "KF41" : "Strf 90"
			case .allies: tier == 0 ? "M113" : "M2A2"
			case .soviet: "BMP"
			case .none: ""
			}
		case .heavyTrack:
			switch tier {
			case 0: 
				switch country.team {
				case .axis: country == .swe ? "Strv 103" : "Leopard 1A5"
				case .allies: "M48"
				case .soviet: "T-55BVM"
				case .none: ""
				}
			case 1: 
				switch country.team {
				case .axis: country == .ger ? "KF51" : "Strv 122"
				case .allies: "M1A1"
				case .soviet: "T-72B"
				case .none: ""
				}
			default:
				switch country.team {
				case .axis: country == .ger ? "KF51" : "Strv 122"
				case .allies: "M1A2"
				case .soviet: "T-90M"
				case .none: ""
				}
			}
		case .heli:
			switch country.team {
			case .axis: self[.transport] ? "NH90" : "Skeldar"
			case .allies: "MH6"
			case .soviet: self[.transport] ? "Mi-8" : "Mi-24"
			case .none: ""
			}
		case .fighter:
			switch country.team {
			case .axis: "Gripen"
			case .allies: "F16"
			case .soviet: "Mig-29"
			case .none: ""
			}
		case .cas:
			switch country.team {
			case .axis: ""
			case .allies: "A-10"
			case .soviet: "Su-25"
			case .none: ""
			}
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
		case _ where isRoad: "road"
		default: ""
		}
	}
}
