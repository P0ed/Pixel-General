/// Flat art laid on a tile: a road is a slab out to each connected edge with a dashed
/// centreline, a bridge a paved deck on piles. Drawn on the tile canvas, over the base.
public enum Roads {

	public enum Tone {
		public static let bed: UInt8 = 176
		public static let mark: UInt8 = 236
		public static let deck: UInt8 = 214
		public static let rail: UInt8 = 96
		public static let pile: UInt8 = 84
	}

	/// Width of the carriageway, in footprint units.
	public static let width: Float = 9

	public static func road(_ directions: [Direction]) -> Model {
		road(directions, tileEdges: .framed)
	}

	private static func road(_ directions: [Direction], tileEdges: Outline.TileEdges) -> Model {
		var outline = Outline.decal
		outline.tileEdges = tileEdges

		func pavement(from: V3, to: V3) -> Solid {
			var solid = Solid.box(from: from, to: to, tone: Tone.bed)
			solid.outline = outline
			return solid
		}

		let half = Volume.footprint / 2
		let near = half - width / 2
		let far = half + width / 2
		var solids = [pavement(from: V3(near, near, 0), to: V3(far, far, 0))]

		for direction in directions {
			let from: V3
			let to: V3
			switch direction {
			case .xPlus: (from, to) = (V3(half, near, 0), V3(Volume.footprint, far, 0))
			case .xMinus: (from, to) = (V3(0, near, 0), V3(half, far, 0))
			case .yPlus: (from, to) = (V3(near, half, 0), V3(far, Volume.footprint, 0))
			case .yMinus: (from, to) = (V3(near, 0, 0), V3(far, half, 0))
			}
			solids.append(pavement(from: from, to: to))
		}

		return Model(solids, lines: directions.map {
			.spoke($0, z: 0, tone: Tone.mark, width: 1, dash: 4.5)
		})
	}

	/// The same carriageway and markings as a road, with a wider deck beneath it.
	/// Paving stays at z = 0 so both approaches meet neighbouring road tiles exactly.
	public static func bridge(along axis: Axis) -> Model {
		let side = Volume.footprint
		let near = side / 2 - 6.75
		let far = side / 2 + 6.75
		let deck = Solid.box(from: V3(0, near, -1.5), to: V3(side, far, 0), tone: Tone.deck)

		var lines: [Line] = [
			Line(from: V3(0, near + 0.75, 0.75), to: V3(side, near + 0.75, 0.75), tone: Tone.rail),
			Line(from: V3(0, far - 0.75, 0.75), to: V3(side, far - 0.75, 0.75), tone: Tone.rail),
		]
		for x in stride(from: Float(7.5), through: side - 7.5, by: (side - 15) / 3) {
			lines.append(Line(from: V3(x, far, -1.5), to: V3(x, far, -6), tone: Tone.pile))
		}

		// The asphalt reaches the ends of the deck and wins the coplanar tie.
		let model = road([.xMinus, .xPlus], tileEdges: .open) + Model([deck], lines: lines)
		return axis == .x ? model : model.rotated(.right)
	}
}
