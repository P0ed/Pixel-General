extension Unit {

	var status: String {
		.makeStatus(pad: 16) { add in
			add("\(stats.shortDescription)")
		} + .makeStatus(pad: 8) { add in
			add("\(stats.starsString)")
		} + .makeStatus(pad: 14) { add in
			add("AM: \(stats.ammo)/\(stats.atm)/\(stats.aam)")
		} + .makeStatus(pad: 10) { add in
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

	var description: String {
		"""
		\(stats.shortDescription)
		
		ATK: \(stats.softAtk) / \(stats.hardAtk) / \(stats.airAtk)
		DEF: \(stats.groundDef) / \(stats.airDef)
		MOV: \(stats.mov) \(stats.moveType)
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
}

extension TacticalState {

	var statusText: String {
		if let selectedUnit {
			units[selectedUnit].status
		} else if let building = buildings[cursor] {
			.makeStatus { add in
				add("\(building.type)")
				add("controller: \(building.country.team)")
			}
		} else {
			"(\(cursor.x), \(cursor.y)) \(map[cursor])"
		}
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
