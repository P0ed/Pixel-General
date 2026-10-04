public extension Ships {

	/// European support ship with a broad helicopter deck and forward island.
	static var karelDoorman: Model {
		let deck: Float = 5.7
		return hull(length: 51, width: 16.5, deck: deck)
		+ Model([
			armour(length: 19.5, width: 12.75, z: deck ... 12.75, x: 6, front: 1.5,
				side: 0.45, corner: 1.05, tone: Tone.house),
			armour(length: 9, width: 12, z: 12.75 ... 15.75, x: 9, front: 0.75,
				corner: 0.75, tone: Tone.house),
			box(length: 4.5, width: 4.5, z: 12 ... 18, x: 0, tone: Tone.turret),
		], lines: windows(x: 9, length: 9, width: 12, z: 13.5)
			+ helipad(x: -15, z: deck + 0.15)
			+ [Line(from: at(-22.5, 0, deck + 0.15), to: at(-4.5, 0, deck + 0.15), tone: 135, dash: 2.25)])
		+ mast(x: 6, from: 15.75, to: 22.5, span: 6)
	}

	/// American roll-on/roll-off transport: long vehicle deck and tall aft accommodation.
	static var bobHope: Model {
		let deck: Float = 5.7
		return hull(length: 52.5, width: 15, deck: deck)
		+ Model([
			armour(length: 33, width: 12.75, z: deck ... 8.25, x: 4.5, corner: 0.9, tone: Tone.cargo),
			armour(length: 11.25, width: 12.75, z: deck ... 15.75, x: -15,
				front: 0.75, side: 0.45, corner: 0.9, tone: Tone.house),
			box(length: 9.75, width: 11.25, z: 15.75 ... 18, x: -15, tone: Tone.house),
			box(length: 3.75, width: 4.5, z: 12 ... 19.8, x: -19.5, tone: Tone.turret),
		], lines: windows(x: -15, length: 9.75, width: 11.25, z: 16.5)
			+ [-6, 3, 12].flatMap { x in
				sides(6.3) { Line(from: at(x, $0, deck + 0.3), to: at(x, $0, 8.1), tone: 120) }
			}) + mast(x: -12.75, from: 18, to: 23.25, span: 4.5)
	}

	/// Soviet landing ship: raised vehicle hold, aft bridge and a visible bow ramp.
	static var ropucha: Model {
		let deck: Float = 4.8
		return hull(length: 48, width: 13.5, deck: deck)
		+ Model([
			armour(length: 27, width: 11.25, z: deck ... 8.25, x: 1.5, front: 0.75,
				corner: 0.9, tone: Tone.deck),
			armour(length: 12, width: 10.5, z: deck ... 12.75, x: -12.75, front: 0.9,
				corner: 0.9, tone: Tone.house),
			box(length: 7.5, width: 9, z: 12.75 ... 15, x: -12, tone: Tone.house),
			box(length: 6, width: 7.5, z: 4.5 ... 7.95, x: 18, tone: Tone.turret),
		], lines: windows(x: -12, length: 7.5, width: 9, z: 13.5)
			+ sides(3.75) { Line(from: at(15, $0, 8.1), to: at(21, $0, 6), tone: 100) })
		+ navalGun(x: 9, z: 8.25, size: 5.25, barrel: 6.75)
		+ mast(x: -12, from: 15, to: 22.5, span: 7.5)
	}

	/// Type 45: stealth-shaped superstructure and a large pyramidal radar mast.
	static var type45: Model {
		let deck: Float = 5.1
		return hull(length: 49.5, width: 13.5, deck: deck)
		+ Model([
			armour(length: 25.5, width: 10.8, z: deck ... 11.7, x: -4.5,
				front: 2.25, rear: 1.5, side: 1.2, corner: 1.5, tone: Tone.house),
			armour(length: 9, width: 8.4, z: 11.7 ... 15, x: 1.5,
				front: 1.05, side: 0.6, corner: 0.9, tone: Tone.house),
			armour(length: 6, width: 6, z: 13.5 ... 24, x: -3.75,
				front: 1.8, rear: 1.8, side: 1.8, corner: 0.9, tone: Tone.house),
			cylinder(at: at(-3.75, 0, 25.5), radius: 2.4, length: 2.25, axis: .z, tone: Tone.mast),
			armour(length: 4.5, width: 6, z: 11.7 ... 17.25, x: -12,
				front: 0.75, side: 0.75, corner: 0.75, tone: Tone.turret),
		], lines: windows(x: 1.5, length: 9, width: 8.4, z: 12.75)
			+ helipad(x: -19.5, z: deck + 0.15))
		+ cells(x: 9.75, z: deck, length: 6, width: 7.5)
		+ navalGun(x: 16.5, z: deck, size: 5.7, barrel: 7.5)
	}

	/// Sovremenny: separated bridge and aft house, two gun turrets and side missile boxes.
	static var sovremenny: Model {
		let deck: Float = 5.1
		return hull(length: 51, width: 13.5, deck: deck)
		+ Model([
			armour(length: 13.5, width: 9.75, z: deck ... 12, x: 1.5,
				front: 0.9, corner: 0.9, tone: Tone.house),
			box(length: 7.5, width: 8.25, z: 12 ... 14.25, x: 3, tone: Tone.house),
			armour(length: 9, width: 9, z: deck ... 10.5, x: -12,
				corner: 0.9, tone: Tone.house),
			box(length: 4.5, width: 4.5, z: 10.5 ... 15, x: -9.75, tone: Tone.turret),
		] + sides(5.25) { armour(length: 10.5, width: 3.75, z: deck ... 9.75, x: 6, y: $0,
			front: 1.5, corner: 0.6, tone: Tone.turret) },
		lines: windows(x: 3, length: 7.5, width: 8.25, z: 12.75))
		+ navalGun(x: 16.5, z: deck, size: 6, barrel: 8.25)
		+ navalGun(x: -19.5, z: deck, size: 6, barrel: -8.25)
		+ mast(x: 0, from: 14.25, to: 23.25, span: 9)
		+ mast(x: -13.5, from: 10.5, to: 18.75, span: 5.25)
	}

	/// Historical Dutch light cruiser: four gun turrets and two tall lattice masts.
	static var deZevenProvincien: Model {
		let deck: Float = 5.25
		return hull(length: 52.5, width: 13.5, deck: deck)
		+ Model([
			armour(length: 22.5, width: 9.75, z: deck ... 9.75, x: -1.5,
				corner: 0.9, tone: Tone.house),
			box(length: 7.5, width: 8.25, z: 9.75 ... 15.75, x: 4.5, tone: Tone.house),
			cylinder(at: at(-3, 0, 12.75), radius: 2.25, length: 7.5, axis: .z, tone: Tone.turret),
			cylinder(at: at(-10.5, 0, 12.75), radius: 2.25, length: 7.5, axis: .z, tone: Tone.turret),
		], lines: windows(x: 4.5, length: 7.5, width: 8.25, z: 13.5))
		+ navalGun(x: 18, z: deck, size: 6, barrel: 7.5)
		+ navalGun(x: 10.5, z: 9.75, size: 6, barrel: 7.5)
		+ navalGun(x: -19.5, z: deck, size: 6, barrel: -7.5)
		+ navalGun(x: -13.5, z: 9.75, size: 6, barrel: -7.5)
		+ mast(x: 3, from: 15.75, to: 24, span: 9)
		+ mast(x: -10.5, from: 16.5, to: 21.75, span: 7.5)
	}

	/// Slava: eight prominent inclined missile canisters, tall bridge and aft radar dome.
	static var slava: Model {
		let deck: Float = 5.7
		return hull(length: 52.5, width: 15.75, deck: deck)
		+ Model([
			armour(length: 19.5, width: 9.75, z: deck ... 13.5, x: -3,
				front: 1.5, corner: 1.05, tone: Tone.house),
			box(length: 7.5, width: 8.25, z: 13.5 ... 16.5, x: 0, tone: Tone.house),
			box(length: 6.75, width: 6, z: 9 ... 16.5, x: -12, tone: Tone.turret),
			cylinder(at: at(-15.75, 0, 18.45), radius: 3.45, length: 2.55, axis: .z, tone: Tone.house),
			armour(length: 6.9, width: 6.9, z: 19.5 ... 22.5, x: -15.75,
				front: 1.8, rear: 1.8, side: 1.8, corner: 1.5, tone: Tone.house),
		] + [-4.5, 0, 4.5, 9].flatMap { x in
			sides(6.45) { GFX.barrel(from: at(x - 3, $0, deck + 0.45),
				to: at(x + 3, $0, deck + 5.25), caliber: 3.15, tone: Tone.turret) }
		}, lines: windows(x: 0, length: 7.5, width: 8.25, z: 14.25)
			+ helipad(x: -21, z: deck + 0.15))
		+ navalGun(x: 18, z: deck, size: 6.75, barrel: 9)
		+ mast(x: -1.5, from: 16.5, to: 25.5, span: 9)
	}
}
