extension Unit {

	var status: String {
		.makeStatus(pad: 12) { add in
			add("\(shortDescription)")
		} + .makeStatus(pad: 10) { add in
			add("\(mpString)\(apString)  \(starsString)")
		} + .makeStatus(pad: 12) { add in
			add(ammoString)
		} + .makeStatus(pad: 9) { add in
			add("INI: \(ini)")
			add("SA: \(softAtk)")
			add("HA: \(hardAtk)")
			add("AA: \(airAtk)")
			add("GD: \(groundDef)")
			add("AD: \(airDef)")
			add("MOV: \(mov)")
			add("ENT: \(ent)")
		}
	}

	private var mpString: String {
		mp == 0 ? " " : "⇧"
	}

	private var apString: String {
		ap == 0 || self[.supply] ? "⦾" : "⦿"
	}

	var description: String {
		"""
		\(shortDescription) \(String(repeating: "★", count: Int(stars)))
		
		ATK: \(softAtk) / \(hardAtk) / \(airAtk)
		DEF: \(groundDef) / \(airDef)
		MOV: \(mov)
		RNG: \(rng)
		
		
		- - - - - - - -
		Cost: \(cost)
		"""
	}
}

extension Unit {

	var starsString: String {
		switch stars {
		case 4: "★★★★"
		case 3: "★★★☆"
		case 2: "★★☆☆"
		case 1: "★☆☆☆"
		default: "☆☆☆☆"
		}
	}

	var ammoString: String {
		!hasAmmo ? "" : String(repeating: ".", count: 0x7 - Int(ammo))
		+ String(repeating: "!", count: Int(ammo))
		+ String(repeating: "*", count: Int(mtm))
		+ String(repeating: ".", count: 0x3 - Int(mtm))
	}
}

extension TacticalState {

	var statusText: String {
		if let selectedUnit {
			units[selectedUnit].status
		} else if let building = buildings[cursor] {
			.makeStatus { add in
				add("\(building.type)")
				add("controller: \(building.country)")
			}
		} else {
			"\(cursor) \(map[cursor])"
		}
	}

	var globalText: String {
		let cs = player.crystals
		let rs = Crystals(rawValue: UInt8(d20.seed & 0xFF))
		return "\(cs) \(rs)"
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
		case .soft: traitDescription ?? "inf"
		case .softWheel: traitDescription ?? "ifv"
		case .lightWheel: traitDescription ?? "ifv"
		case .mediumWheel: traitDescription ?? "ifv"
		case .lightTrack: traitDescription ?? "ifv"
		case .mediumTrack: traitDescription ?? "ifv"
		case .heavyTrack: "tank"
		case .air: "heli"
		}
	}

	private var traitDescription: String? {
		self[.art] ? "art" : self[.aa] ? "anti-air" : self[.supply] ? "supply" : .none
	}
}

extension Unit {
	var shortDescription: String {
		"\(country) \(typeDescription)"
	}
}

extension Crystals: CustomStringConvertible {

	var description: String {
		(0 ..< 4).map { i in self[i].symbol }.joined()
	}
}

extension Crystal {

	var symbol: String {
		switch self {
		case .red: "♟"
		case .amber: "♞"
		case .turquoise: "♝"
		case .blue: "♜"
		}
	}
}
