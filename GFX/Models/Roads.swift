/// Flat art laid over the tile base. Paving extends to each connected edge, and bridges add a deck on piles.
public enum Roads {

	public enum Tone {
		public static let bed: UInt8 = 172
		public static let pile: UInt8 = 96
	}

	/// Width of the carriageway, in footprint units.
	public static let width: Float = 6

	public static func road(_ directions: [Direction]) -> Model {
		func pavement(from: V3, to: V3) -> Solid {
			var solid = Solid.box(from: from, to: to, tone: Tone.bed)
			solid.outline = .connectedDecal
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

		return Model(solids)
	}

	public static func bridge(along axis: Axis) -> Model {
		let side = Volume.footprint
		let near = side / 2 - width / 2
		let far = side / 2 + width / 2

		let piles: [Solid] = stride(from: Float(8), through: side - 8, by: 8).map { x in
			.box(from: V3(x, near, -3), to: V3(x, far, -1), tone: Tone.pile)
		}

		let model = Model(piles) + road([.xMinus, .xPlus])
		return axis == .x ? model : model.rotated(.right)
	}
}
