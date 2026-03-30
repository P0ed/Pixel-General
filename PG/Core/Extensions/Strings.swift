extension XY: CustomStringConvertible {
	var description: String { "[\(x), \(y)]" }
}

extension Unit {

	var status: String {
		.makeStatus(pad: 12) { add in
			add("\(typeDescription)")
		} + .makeStatus(pad: 10) { add in
			add("\(mpString)\(apString)  \(starsString)")
		} + .makeStatus(pad: 9) { add in
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

	private var mpString: String { canMove ? "⇧" : " " }
	private var apString: String { canAttack ? "⦿" : "⦾" }
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
		String(repeating: "•", count: Int(ammo))
		+ String(repeating: "_", count: max(0, Int(maxAmmo) - Int(ammo)))
	}
}

extension TacticalState {

	var status: Status {
		if let selectedUnit {
			Status(
				text: units[selectedUnit].status,
				action: .init(units[selectedUnit].country.flag)
			)
		} else if let building = buildings[cursor] {
			Status(
				text: "\(cursor) \(building.type)",
				action: .init(building.country.flag)
			)
		} else {
			Status(text: "\(cursor) \(map[cursor])", action: .init(""))
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
		case .soft: traitDescription ?? "inf"
		case .softWheel: traitDescription ?? "ifv"
		case .lightWheel: traitDescription ?? "ifv"
		case .lightTrack: traitDescription ?? "ifv"
		case .heavyTrack: "tank"
		case .heli: "heli"
		case .jet: "jet"
		}
	}

	private var traitDescription: String? {
		self[.art] ? "art" : self[.aa] ? "anti-air" : self[.supply] ? "supply" : .none
	}

	var shortDescription: String {
		"\(country) \(typeDescription)"
	}
}

extension Terrain: CustomStringConvertible {

	var description: String {
		switch self {
		case .river00, .river01, .river10, .river11: "river"
		case .bridge01, .bridge10: "bridge"
		case .field: "field"
		case .forest: "forest"
		case .hill, .forestHill: "hill"
		case .mountain: "mountain"
		case .city: "city"
		case .airfield: "airfield"
		case _ where isRoad: "road"
		default: ""
		}
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
