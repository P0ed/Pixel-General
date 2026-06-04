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
			if self[.elite] {
				switch country.team {
				case .axis: "KSK"
				case .allies: "Delta Force"
				case .soviet: "Speznas"
				}
			} else {
				"Infantry"
			}
		case .art:
			switch country.team {
			case .allies: "M777"
			default: hardAtk > 6 ? "155mm" : "105mm"
			}
		case .wheelArt: "Bohdana"
		case .trackArt:
			switch country.team {
			case .axis: "PzH 2000"
			case .allies: "M270"
			case .soviet: "2С3"
			}
		case .aa: "40mm L/70"
		case .wheelAA: "Neva"
		case .trackAA: "Lvkv 90"
		case .lightWheel: "Boxer"
		case .lightTrack:
			switch country.team {
			case .axis: self[.elite] ? "KF41" : "Strf 90"
			case .allies: hardAtk > 5 ? "M2A2" : "M113"
			case .soviet: "BMP"
			}
		case .heavyTrack:
			switch country.team {
			case .axis: hardAtk > 14 ? "KF51" : hardAtk > 12 ? "Strv 122" : "Leopard 1A5"
			case .allies: hardAtk > 12 ? "M1A2" : "M48"
			case .soviet: hardAtk > 12 ? "T-90M" : hardAtk > 10 ? "T-72B" : "T-55BVM"
			}
		case .heli: 
			switch country.team {
			case .axis: self[.transport] ? "NH90" : "Skeldar"
			case .allies: "MH6"
			case .soviet: self[.transport] ? "Mi-8" : "Mi-24"
			}
		case .jet:
			switch country.team {
			case .axis: "Gripen"
			case .allies: "F16"
			case .soviet: "Mig-29"
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
