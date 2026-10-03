public extension Ships {

	/// European support ship with a broad helicopter deck and forward island.
	static var karelDoorman: Model {
		let deck: Float = 3.8
		return hull(length: 34, width: 11, deck: deck)
		+ Model([
			armour(length: 13, width: 8.5, z: deck ... 8.5, x: 4, front: 1,
				side: 0.3, corner: 0.7, tone: Tone.house),
			armour(length: 6, width: 8, z: 8.5 ... 10.5, x: 6, front: 0.5,
				corner: 0.5, tone: Tone.house),
			box(length: 3, width: 3, z: 8 ... 12, x: 0, tone: Tone.turret),
		], lines: windows(x: 6, length: 6, width: 8, z: 9)
			+ helipad(x: -10, z: deck + 0.1)
			+ [Line(from: at(-15, 0, deck + 0.1), to: at(-3, 0, deck + 0.1), tone: 135, dash: 1.5)])
		+ mast(x: 4, from: 10.5, to: 15, span: 4)
	}

	/// American roll-on/roll-off transport: long vehicle deck and tall aft accommodation.
	static var bobHope: Model {
		let deck: Float = 3.8
		return hull(length: 35, width: 10, deck: deck)
		+ Model([
			armour(length: 22, width: 8.5, z: deck ... 5.5, x: 3, corner: 0.6, tone: Tone.cargo),
			armour(length: 7.5, width: 8.5, z: deck ... 10.5, x: -10,
				front: 0.5, side: 0.3, corner: 0.6, tone: Tone.house),
			box(length: 6.5, width: 7.5, z: 10.5 ... 12, x: -10, tone: Tone.house),
			box(length: 2.5, width: 3, z: 8 ... 13.2, x: -13, tone: Tone.turret),
		], lines: windows(x: -10, length: 6.5, width: 7.5, z: 11)
			+ [-4, 2, 8].flatMap { x in
				sides(4.2) { Line(from: at(x, $0, deck + 0.2), to: at(x, $0, 5.4), tone: 120) }
			}) + mast(x: -8.5, from: 12, to: 15.5, span: 3)
	}

	/// Soviet landing ship: raised vehicle hold, aft bridge and a visible bow ramp.
	static var ropucha: Model {
		let deck: Float = 3.2
		return hull(length: 32, width: 9, deck: deck)
		+ Model([
			armour(length: 18, width: 7.5, z: deck ... 5.5, x: 1, front: 0.5,
				corner: 0.6, tone: Tone.deck),
			armour(length: 8, width: 7, z: deck ... 8.5, x: -8.5, front: 0.6,
				corner: 0.6, tone: Tone.house),
			box(length: 5, width: 6, z: 8.5 ... 10, x: -8, tone: Tone.house),
			box(length: 4, width: 5, z: 3 ... 5.3, x: 12, tone: Tone.turret),
		], lines: windows(x: -8, length: 5, width: 6, z: 9)
			+ sides(2.5) { Line(from: at(10, $0, 5.4), to: at(14, $0, 4), tone: 100) })
		+ navalGun(x: 6, z: 5.5, size: 3.5, barrel: 4.5)
		+ mast(x: -8, from: 10, to: 15, span: 5)
	}

	/// Type 45: stealth-shaped superstructure and a large pyramidal radar mast.
	static var type45: Model {
		let deck: Float = 3.4
		return hull(length: 33, width: 9, deck: deck)
		+ Model([
			armour(length: 17, width: 7.2, z: deck ... 7.8, x: -3,
				front: 1.5, rear: 1, side: 0.8, corner: 1, tone: Tone.house),
			armour(length: 6, width: 5.6, z: 7.8 ... 10, x: 1,
				front: 0.7, side: 0.4, corner: 0.6, tone: Tone.house),
			armour(length: 4, width: 4, z: 9 ... 16, x: -2.5,
				front: 1.2, rear: 1.2, side: 1.2, corner: 0.6, tone: Tone.house),
			cylinder(at: at(-2.5, 0, 17), radius: 1.6, length: 1.5, axis: .z, tone: Tone.mast),
			armour(length: 3, width: 4, z: 7.8 ... 11.5, x: -8,
				front: 0.5, side: 0.5, corner: 0.5, tone: Tone.turret),
		], lines: windows(x: 1, length: 6, width: 5.6, z: 8.5)
			+ helipad(x: -13, z: deck + 0.1))
		+ cells(x: 6.5, z: deck, length: 4, width: 5)
		+ navalGun(x: 11, z: deck, size: 3.8, barrel: 5)
	}

	/// Sovremenny: separated bridge and aft house, two gun turrets and side missile boxes.
	static var sovremenny: Model {
		let deck: Float = 3.4
		return hull(length: 34, width: 9, deck: deck)
		+ Model([
			armour(length: 9, width: 6.5, z: deck ... 8, x: 1,
				front: 0.6, corner: 0.6, tone: Tone.house),
			box(length: 5, width: 5.5, z: 8 ... 9.5, x: 2, tone: Tone.house),
			armour(length: 6, width: 6, z: deck ... 7, x: -8,
				corner: 0.6, tone: Tone.house),
			box(length: 3, width: 3, z: 7 ... 10, x: -6.5, tone: Tone.turret),
		] + sides(3.5) { armour(length: 7, width: 2.5, z: deck ... 6.5, x: 4, y: $0,
			front: 1, corner: 0.4, tone: Tone.turret) },
		lines: windows(x: 2, length: 5, width: 5.5, z: 8.5))
		+ navalGun(x: 11, z: deck, size: 4, barrel: 5.5)
		+ navalGun(x: -13, z: deck, size: 4, barrel: -5.5)
		+ mast(x: 0, from: 9.5, to: 15.5, span: 6)
		+ mast(x: -9, from: 7, to: 12.5, span: 3.5)
	}

	/// Historical Dutch light cruiser: four gun turrets and two tall lattice masts.
	static var deZevenProvincien: Model {
		let deck: Float = 3.5
		return hull(length: 35, width: 9, deck: deck)
		+ Model([
			armour(length: 15, width: 6.5, z: deck ... 6.5, x: -1,
				corner: 0.6, tone: Tone.house),
			box(length: 5, width: 5.5, z: 6.5 ... 10.5, x: 3, tone: Tone.house),
			cylinder(at: at(-2, 0, 8.5), radius: 1.5, length: 5, axis: .z, tone: Tone.turret),
			cylinder(at: at(-7, 0, 8.5), radius: 1.5, length: 5, axis: .z, tone: Tone.turret),
		], lines: windows(x: 3, length: 5, width: 5.5, z: 9))
		+ navalGun(x: 12, z: deck, size: 4, barrel: 5)
		+ navalGun(x: 7, z: 6.5, size: 4, barrel: 5)
		+ navalGun(x: -13, z: deck, size: 4, barrel: -5)
		+ navalGun(x: -9, z: 6.5, size: 4, barrel: -5)
		+ mast(x: 2, from: 10.5, to: 16, span: 6)
		+ mast(x: -7, from: 11, to: 14.5, span: 5)
	}

	/// Slava: eight prominent inclined missile canisters, tall bridge and aft radar dome.
	static var slava: Model {
		let deck: Float = 3.8
		return hull(length: 35, width: 10.5, deck: deck)
		+ Model([
			armour(length: 13, width: 6.5, z: deck ... 9, x: -2,
				front: 1, corner: 0.7, tone: Tone.house),
			box(length: 5, width: 5.5, z: 9 ... 11, x: 0, tone: Tone.house),
			box(length: 4.5, width: 4, z: 6 ... 11, x: -8, tone: Tone.turret),
			cylinder(at: at(-10.5, 0, 12.3), radius: 2.3, length: 1.7, axis: .z, tone: Tone.house),
			armour(length: 4.6, width: 4.6, z: 13 ... 15, x: -10.5,
				front: 1.2, rear: 1.2, side: 1.2, corner: 1, tone: Tone.house),
		] + [-3, 0, 3, 6].flatMap { x in
			sides(4.3) { GFX.barrel(from: at(x - 2, $0, deck + 0.3),
				to: at(x + 2, $0, deck + 3.5), caliber: 2.1, tone: Tone.turret) }
		}, lines: windows(x: 0, length: 5, width: 5.5, z: 9.5)
			+ helipad(x: -14, z: deck + 0.1))
		+ navalGun(x: 12, z: deck, size: 4.5, barrel: 6)
		+ mast(x: -1, from: 11, to: 17, span: 6)
	}
}
