/// Flat art laid on a tile: a road is a slab out to each connected edge with a dashed
/// centreline, a bridge a plank deck on piles. Drawn on the tile canvas, over the base.
public enum Roads {

	public enum Tone {
		public static let bed: UInt8 = 176
		public static let mark: UInt8 = 236
		public static let deck: UInt8 = 214
		public static let rail: UInt8 = 96
		public static let pile: UInt8 = 84
	}

	/// Width of the carriageway, in footprint units.
	public static let width: Float = 6

	public static func road(_ directions: [Direction]) -> Model {
		let half = Volume.footprint / 2
		let near = half - width / 2
		let far = half + width / 2
		var solids = [Solid.box(from: V3(near, near, 0), to: V3(far, far, 0), tone: Tone.bed)]

		for direction in directions {
			let from: V3
			let to: V3
			switch direction {
			case .xPlus: (from, to) = (V3(half, near, 0), V3(half * 2, far, 0))
			case .xMinus: (from, to) = (V3(0, near, 0), V3(half, far, 0))
			case .yPlus: (from, to) = (V3(near, half, 0), V3(far, half * 2, 0))
			case .yMinus: (from, to) = (V3(near, 0, 0), V3(far, half, 0))
			}
			solids.append(.box(from: from, to: to, tone: Tone.bed))
		}

		return Model(solids, lines: directions.map {
			.spoke($0, z: 0, tone: Tone.mark, width: 1, dash: 3)
		})
	}

	/// Deck spanning the tile along `axis`, railed on both sides and carried on four piles.
	public static func bridge(along axis: Axis) -> Model {
		let side = Volume.footprint
		let near = side / 2 - 4.5
		let far = side / 2 + 4.5
		let deck = Solid.box(from: V3(0, near, 1), to: V3(side, far, 2), tone: Tone.deck)

		var lines: [Line] = [
			Line(from: V3(0, near + 0.5, 2), to: V3(side, near + 0.5, 2), tone: Tone.rail),
			Line(from: V3(0, far - 0.5, 2), to: V3(side, far - 0.5, 2), tone: Tone.rail),
		]
		for x in stride(from: Float(5), through: side - 5, by: (side - 10) / 3) {
			lines.append(Line(from: V3(x, far, 1), to: V3(x, far, -2), tone: Tone.pile))
		}

		let model = Model([deck], lines: lines)
		return axis == .x ? model : model.rotated(.right)
	}
}
