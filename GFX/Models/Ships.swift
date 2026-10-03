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
		let deck: Float = 3.3
		return hull(length: 32, width: 8.5, deck: deck)
		+ Model([
			armour(length: 10.5, width: 6.5, z: deck ... 7.7, x: -2.8,
				front: 1.2, rear: 0.5, side: 0.6, corner: 1, tone: Tone.house),
			armour(length: 5, width: 5.4, z: 7.7 ... 9.4, x: -1.6,
				front: 0.6, rear: 0.4, side: 0.2, corner: 0.5, tone: Tone.house),
			armour(length: 3.5, width: 3.2, z: deck ... 8.2, x: -8.5,
				front: 0.5, side: 0.3, corner: 0.6, tone: 150),
			hatch(x: -13, z: deck, radius: 1, tone: Tone.deck),
		], lines: windows(x: -1.6, length: 5, width: 5.4, z: 8.2)
			+ grille(x: -8.5, z: 8.25, length: 2, width: 2, tone: Tone.mast)
			+ helipad(x: -12.4, z: deck + 0.1))
		+ cells(x: 4, z: deck, length: 4.5, width: 5)
		+ navalGun(x: 10, z: deck, size: 4.5, barrel: 6)
		+ mast(x: -2.5, from: 9.4, to: 15, span: 5)
	}

	/// Cruiser with a broader hull, two gun houses, a large missile deck and a second radar mast.
	public static var ticonderoga: Model {
		let deck: Float = 3.8
		return hull(length: 34, width: 9.5, deck: deck)
		+ Model([
			armour(length: 12, width: 7.5, z: deck ... 9, x: -2,
				front: 1.3, rear: 0.6, side: 0.6, corner: 1, tone: Tone.house),
			armour(length: 5.5, width: 6, z: 9 ... 11, x: -1.5,
				front: 0.6, rear: 0.3, side: 0.3, corner: 0.7, tone: Tone.house),
			armour(length: 3.5, width: 3.5, z: deck ... 10, x: -8.5,
				front: 0.5, side: 0.3, corner: 0.7, tone: 145),
		], lines: windows(x: -1.5, length: 5.5, width: 6, z: 9.6)
			+ grille(x: -8.5, z: 10.05, length: 2, width: 2, tone: Tone.mast))
		+ cells(x: 5.3, z: deck, length: 5, width: 6)
		+ navalGun(x: 11.5, z: deck, size: 5, barrel: 7.5)
		+ navalGun(x: -13, z: deck, size: 4.5, barrel: -7)
		+ mast(x: -2.5, from: 11, to: 16, span: 5.5)
		+ mast(x: -8.5, from: 10, to: 13, span: 3)
	}
}

extension Ships {

	static func outline(length: Float, width: Float) -> [(Float, Float)] {
		let l = length / 2, w = width / 2
		return [(-l, -w + 1.2), (-l + 1.2, -w), (l - 6, -w), (l, 0),
			(l - 6, w), (-l + 1.2, w), (-l, w - 1.2)]
	}

	/// The sides flare above the waterline; the prow rakes forward to a pointed deck.
	static func hull(length: Float, width: Float, deck: Float) -> Model {
		var hull = prism(outline(length: length, width: width), z: 0 ... deck - 0.25, tone: Tone.hull)
		hull.planes += [
			Plane(normal: V3(1, 0, -0.5), through: at(length / 2, 0, deck - 0.25)),
			Plane(normal: V3(0, 1, -0.25), through: at(0, width / 2, deck - 0.25)),
			Plane(normal: V3(0, -1, -0.25), through: at(0, -width / 2, deck - 0.25)),
		]
		var waterline = hull.toned(95)
		waterline.planes.append(Plane(normal: V3(0, 0, 1), offset: 0.65))
		waterline.to.z = 0.65
		let edge = outline(length: length - 0.6, width: width - 0.6)
		var lines = edge.indices.map { i in
			Line(from: at(edge[i].0, edge[i].1, deck + 0.25),
				to: at(edge[(i + 1) % edge.count].0, edge[(i + 1) % edge.count].1, deck + 0.25), tone: 120)
		}
		lines += [-12, -6, 0, 6].flatMap { x in
			sides((width - 0.6) / 2) {
				Line(from: at(x, $0, deck), to: at(x, $0, deck + 0.7), tone: 120)
			}
		}
		return Model([
			waterline, hull, prism(edge, z: deck - 0.3 ... deck, tone: Tone.deck),
		], lines: lines)
	}

	static func windows(x: Float, length: Float, width: Float, z: Float) -> [Line] {
		[
			Line(from: at(x + length / 2 + 0.05, -width / 2 + 0.8, z),
				to: at(x + length / 2 + 0.05, width / 2 - 0.8, z), tone: Tone.mast, dash: 0.8),
		] + sides(width / 2 + 0.05) {
			Line(from: at(x - length / 2 + 0.7, $0, z), to: at(x + length / 2 - 0.7, $0, z), tone: 95, dash: 0.8)
		}
	}

	static func cells(x: Float, z: Float, length: Float, width: Float) -> Model {
		Model([
			box(length: length, width: width, z: z ... z + 0.35, x: x, tone: 175),
		], lines: grille(x: x, z: z + 0.4, length: length - 0.6, width: width - 0.6, tone: 100)
			+ [-width / 6, width / 6].map {
				Line(from: at(x - length / 2 + 0.3, $0, z + 0.4), to: at(x + length / 2 - 0.3, $0, z + 0.4), tone: 100)
			})
	}

	static func navalGun(x: Float, z: Float, size: Float, barrel length: Float) -> Model {
		let direction: Float = length > 0 ? 1 : -1
		let start = at(x + direction * 1.5, 0, z + 1.5)
		let end = at(x + length, 0, z + 2.5)
		return turret(length: size, width: size - 0.5, z: z + 0.1 ... z + 2.5, x: x,
			front: length > 0 ? 1 : 0.4, rear: length > 0 ? 0.4 : 1, side: 0.6, corner: 0.8, tone: Tone.turret)
		+ Model([
			GFX.barrel(from: start, to: end, caliber: 1.1, tone: Tone.barrel),
		], lines: [Line(from: start + V3(0, 0, 0.55), to: end + V3(0, 0, 0.55), tone: Tone.barrel)])
	}

	static func mast(x: Float, from base: Float, to top: Float, span: Float) -> Model {
		Model([
			cylinder(at: at(x, 0, top - 0.7), radius: 1, length: 1.3, axis: .z, tone: Tone.house),
		], lines: [
			Line(from: at(x, 0, base), to: at(x, 0, top + 1.5), tone: Tone.mast),
			Line(from: at(x, -span / 2, top - 1.8), to: at(x, span / 2, top - 1.8), tone: Tone.mast),
			Line(from: at(x - 1.5, 0, top + 0.5), to: at(x + 1.5, 0, top + 0.5), tone: Tone.mast),
			Line(from: at(x - 1.5, 0, base), to: at(x, 0, top - 1.8), tone: 115),
		])
	}

	static func helipad(x: Float, z: Float) -> [Line] {
		[
			Line(from: at(x - 1.5, -1.5, z), to: at(x - 1.5, 1.5, z), tone: 135),
			Line(from: at(x + 1.5, -1.5, z), to: at(x + 1.5, 1.5, z), tone: 135),
			Line(from: at(x - 1.5, 0, z), to: at(x + 1.5, 0, z), tone: 135),
		]
	}
}
