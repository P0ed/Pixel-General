extension Unit {

	var status: String {
		.makeStatus(pad: 12) { add in
			add("\(stats.shortDescription)")
		} + .makeStatus(pad: 10) { add in
			add("\(mpString)\(apString)  \(stats.starsString)")
		} + .makeStatus(pad: 12) { add in
			add(stats.ammoString)
		} + .makeStatus(pad: 9) { add in
			add("INI: \(stats.ini)")
			add("SA: \(stats.softAtk)")
			add("HA: \(stats.hardAtk)")
			add("AA: \(stats.airAtk)")
			add("GD: \(stats.groundDef)")
			add("AD: \(stats.airDef)")
			add("MOV: \(stats.mov)")
			add("ENT: \(stats.ent)")
		}
	}

	private var mpString: String {
		stats.mp == 0 ? " " : "⇧"
	}

	private var apString: String {
		stats.ap == 0 || stats[.supply] ? "⦾" : "⦿"
	}

	var description: String {
		"""
		\(stats.shortDescription) \(String(repeating: "★", count: Int(stats.stars)))
		
		ATK: \(stats.softAtk) / \(stats.hardAtk) / \(stats.airAtk)
		DEF: \(stats.groundDef) / \(stats.airDef)
		MOV: \(stats.mov)
		RNG: \(stats.rng)
		
		
		- - - - - - - -
		Cost: \(cost)
		"""
	}
}

extension Stats {

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

extension MenuState where State: ~Copyable {

	var statusText: String { items[cursor].text }
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

extension Stats {

	var shortDescription: String {
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
		"\(country) \(stats.shortDescription)"
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
		case .red: "♚"
		case .amber: "♛"
		case .turquoise: "♜"
		case .blue: "♝"
		}
	}
}
