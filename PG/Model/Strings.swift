extension XY: CustomStringConvertible {
	var description: String { "[\(x), \(y)]" }
}

extension Unit {

	var status: String {
		.make { status in
			status += "\(self[.aux] ? "☆" : "★") \(typeDescription)"
			status.pad(to: 12)
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

extension TacticalState {

	var status: Status {
		if player.type != .human {
			Status(text: "\(player.country) turn")
		} else if let selectedUnit {
			Status(
				text: units[selectedUnit.index].status,
				action: .init(units[selectedUnit.index].country.flag)
			)
		} else if map[cursor].isBuilding {
			Status(
				text: "\(cursor) \(map[cursor])",
				action: .init(control[cursor].flag)
			)
		} else {
			Status(text: "\(cursor) \(map[cursor])", action: .init("day \(day)"))
		}
	}
}

extension String {

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

extension Unit {

	var typeDescription: String {
		switch type {
		case .soft:
			if self[.art] {
				switch country.team {
				case .allies: "M777"
				default: hardAtk > 6 ? "155mm" : "105mm"
				}
			} else if self[.elite] {
				switch country.team {
				case .axis: "KSK"
				case .allies: "Delta Force"
				case .soviet: "Speznas"
				}
			} else {
				"Infantry"
			}
		case .softWheel:
			if self[.aa] {
				"Neva"
			} else if self[.art] {
				"Bohdana"
			} else if self[.supply] {
				"Truck"
			} else {
				""
			}
		case .lightWheel:
			"Boxer"
		case .lightTrack:
			if self[.aa] {
				"Lvkv 90"
			} else if self[.art] {
				"PzH 2000"
			} else {
				switch country.team {
				case .axis: "Strf 90"
				case .allies: hardAtk > 5 ? "M2A2" : "M113"
				case .soviet: "BMP"
				}
			}
		case .heavyTrack:
			switch country.team {
			case .axis: hardAtk > 12 ? "Strv 122" : "Leopard 1"
			case .allies: hardAtk > 12 ? "M1A2" : "M48"
			case .soviet: hardAtk > 12 ? "T-90M" : hardAtk > 10 ? "T-72B" : "T-55BVM"
			}
		case .heli: 
			switch country.team {
			case .axis: "H135"
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

	var shortDescription: String {
		"\(country) \(typeDescription)"
	}
}

extension Terrain: CustomStringConvertible {

	var description: String {
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
