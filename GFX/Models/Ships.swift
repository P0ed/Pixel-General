/// Naval units, authored bow-first along `+x` and floating on the tile surface.
public enum Ships {

	public enum Tone {
		public static let hull: UInt8 = 150
		public static let deck: UInt8 = 195
		public static let house: UInt8 = 225
		public static let turret: UInt8 = 180
		public static let barrel: UInt8 = 150
		public static let mast: UInt8 = 72
		public static let cargo: UInt8 = 205
	}

	/// Destroyer with a raked bow, glazed bridge, radar mast, missile cells and a forward gun.
	public static var arleighBurke: Model {
		let deck: Float = 4.95
		return hull(length: 48, width: 12.75, deck: deck)
		+ Model([
			armour(length: 15.75, width: 9.75, z: deck ... 11.55, x: -4.2,
				front: 1.8, rear: 0.75, side: 0.9, corner: 1.5, tone: Tone.house),
			armour(length: 7.5, width: 8.1, z: 11.55 ... 14.1, x: -2.4,
				front: 0.9, rear: 0.6, side: 0.3, corner: 0.75, tone: Tone.house),
			armour(length: 5.25, width: 4.8, z: deck ... 12.3, x: -12.75,
				front: 0.75, side: 0.45, corner: 0.9, tone: 150),
			hatch(x: -19.5, z: deck, radius: 1.5, tone: Tone.deck),
		], lines: windows(x: -2.4, length: 7.5, width: 8.1, z: 12.3)
			+ grille(x: -12.75, z: 12.375, length: 3, width: 3, tone: Tone.mast)
			+ helipad(x: -18.6, z: deck + 0.15))
		+ cells(x: 6, z: deck, length: 6.75, width: 7.5)
		+ navalGun(x: 15, z: deck, size: 6.75, barrel: 9)
		+ mast(x: -3.75, from: 14.1, to: 22.5, span: 7.5)
	}

	/// Cruiser with a broader hull, two gun houses, a large missile deck and a second radar mast.
	public static var ticonderoga: Model {
		let deck: Float = 5.7
		return hull(length: 51, width: 14.25, deck: deck)
		+ Model([
			armour(length: 18, width: 11.25, z: deck ... 13.5, x: -3,
				front: 1.95, rear: 0.9, side: 0.9, corner: 1.5, tone: Tone.house),
			armour(length: 8.25, width: 9, z: 13.5 ... 16.5, x: -2.25,
				front: 0.9, rear: 0.45, side: 0.45, corner: 1.05, tone: Tone.house),
			armour(length: 5.25, width: 5.25, z: deck ... 15, x: -12.75,
				front: 0.75, side: 0.45, corner: 1.05, tone: 145),
		], lines: windows(x: -2.25, length: 8.25, width: 9, z: 14.4)
			+ grille(x: -12.75, z: 15.075, length: 3, width: 3, tone: Tone.mast))
		+ cells(x: 7.95, z: deck, length: 7.5, width: 9)
		+ navalGun(x: 17.25, z: deck, size: 7.5, barrel: 11.25)
		+ navalGun(x: -19.5, z: deck, size: 6.75, barrel: -10.5)
		+ mast(x: -3.75, from: 16.5, to: 24, span: 8.25)
		+ mast(x: -12.75, from: 15, to: 19.5, span: 4.5)
	}
}

extension Ships {

	static func outline(length: Float, width: Float) -> [(Float, Float)] {
		let l = length / 2, w = width / 2
		return [(-l, -w + 1.8), (-l + 1.8, -w), (l - 9, -w), (l, 0),
			(l - 9, w), (-l + 1.8, w), (-l, w - 1.8)]
	}

	/// The sides flare above the waterline; the prow rakes forward to a pointed deck.
	static func hull(length: Float, width: Float, deck: Float) -> Model {
		var hull = prism(outline(length: length, width: width), z: 0 ... deck - 0.375, tone: Tone.hull)
		hull.planes += [
			Plane(normal: V3(1, 0, -0.5), through: at(length / 2, 0, deck - 0.375)),
			Plane(normal: V3(0, 1, -0.25), through: at(0, width / 2, deck - 0.375)),
			Plane(normal: V3(0, -1, -0.25), through: at(0, -width / 2, deck - 0.375)),
		]
		var waterline = hull.toned(95)
		waterline.planes.append(Plane(normal: V3(0, 0, 1), offset: 0.975))
		waterline.to.z = 0.975
		let edge = outline(length: length - 0.9, width: width - 0.9)
		var lines = edge.indices.map { i in
			Line(from: at(edge[i].0, edge[i].1, deck + 0.375),
				to: at(edge[(i + 1) % edge.count].0, edge[(i + 1) % edge.count].1, deck + 0.375), tone: 120)
		}
		lines += [-18, -9, 0, 9].flatMap { x in
			sides((width - 0.9) / 2) {
				Line(from: at(x, $0, deck), to: at(x, $0, deck + 1.05), tone: 120)
			}
		}
		return Model([
			waterline, hull, prism(edge, z: deck - 0.45 ... deck, tone: Tone.deck),
		], lines: lines)
	}

	static func windows(x: Float, length: Float, width: Float, z: Float) -> [Line] {
		[
			Line(from: at(x + length / 2 + 0.075, -width / 2 + 1.2, z),
				to: at(x + length / 2 + 0.075, width / 2 - 1.2, z), tone: Tone.mast, dash: 1.2),
		] + sides(width / 2 + 0.075) {
			Line(from: at(x - length / 2 + 1.05, $0, z), to: at(x + length / 2 - 1.05, $0, z), tone: 95, dash: 1.2)
		}
	}

	static func cells(x: Float, z: Float, length: Float, width: Float) -> Model {
		Model([
			box(length: length, width: width, z: z ... z + 0.525, x: x, tone: 175),
		], lines: grille(x: x, z: z + 0.6, length: length - 0.9, width: width - 0.9, tone: 100)
			+ [-width / 6, width / 6].map {
				Line(from: at(x - length / 2 + 0.45, $0, z + 0.6), to: at(x + length / 2 - 0.45, $0, z + 0.6), tone: 100)
			})
	}

	static func navalGun(x: Float, z: Float, size: Float, barrel length: Float) -> Model {
		let direction: Float = length > 0 ? 1 : -1
		let start = at(x + direction * 2.25, 0, z + 2.25)
		let end = at(x + length, 0, z + 3.75)
		return turret(length: size, width: size - 0.75, z: z + 0.15 ... z + 3.75, x: x,
			front: length > 0 ? 1.5 : 0.6, rear: length > 0 ? 0.6 : 1.5, side: 0.9, corner: 1.2, tone: Tone.turret)
		+ Model([
			GFX.barrel(from: start, to: end, caliber: 1.65, tone: Tone.barrel),
		], lines: [Line(from: start + V3(0, 0, 0.825), to: end + V3(0, 0, 0.825), tone: Tone.barrel)])
	}

	static func mast(x: Float, from base: Float, to top: Float, span: Float) -> Model {
		Model([
			cylinder(at: at(x, 0, top - 1.05), radius: 1.5, length: 1.95, axis: .z, tone: Tone.house),
		], lines: [
			Line(from: at(x, 0, base), to: at(x, 0, top + 2.25), tone: Tone.mast),
			Line(from: at(x, -span / 2, top - 2.7), to: at(x, span / 2, top - 2.7), tone: Tone.mast),
			Line(from: at(x - 2.25, 0, top + 0.75), to: at(x + 2.25, 0, top + 0.75), tone: Tone.mast),
			Line(from: at(x - 2.25, 0, base), to: at(x, 0, top - 2.7), tone: 115),
		])
	}

	static func helipad(x: Float, z: Float) -> [Line] {
		[
			Line(from: at(x - 2.25, -2.25, z), to: at(x - 2.25, 2.25, z), tone: 135),
			Line(from: at(x + 2.25, -2.25, z), to: at(x + 2.25, 2.25, z), tone: 135),
			Line(from: at(x - 2.25, 0, z), to: at(x + 2.25, 0, z), tone: 135),
		]
	}
}
