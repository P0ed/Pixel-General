/// Buildings drawn on a tile: rendered with `Renderer.tile`, never leaving the footprint.
public enum Settlements {

	public enum Tone {
		public static let wall: UInt8 = 235
		public static let roof: UInt8 = 185
		public static let rampart: UInt8 = 215
	}

	public static var city: Model {
		let centres: [Float] = [6, 16, 26]
		var solids: [Solid] = []

		for (row, x) in centres.enumerated() {
			for (column, y) in centres.enumerated() where !(row == 1 && column == 1) {
				let tall = row == 1 || column == 1
				solids += house(
					x: x,
					y: y,
					length: 8,
					width: 7,
					walls: tall ? 6 : 4,
					roof: 4,
					ridge: (row + column).isMultiple(of: 2) ? .x : .y
				)
			}
		}

		return Model(solids)
	}

	public static func village(facing: Direction) -> Model {
		let base = Model(
			house(x: 9, y: 11, length: 9, width: 7, walls: 4, roof: 4, ridge: .x)
				+ house(x: 8, y: 22, length: 7, width: 6, walls: 3.5, roof: 3.5, ridge: .y)
				+ house(x: 19, y: 17, length: 7, width: 7, walls: 3.5, roof: 4, ridge: .x)
		)

		switch facing {
		case .xMinus: return base
		case .yMinus: return base.rotated(.right)
		case .xPlus: return base.rotated(.half)
		case .yPlus: return base.rotated(.left)
		}
	}

	public static var fort: Model {
		let inset: Float = 5
		let side = Volume.footprint
		let near = inset
		let far = side - inset
		var solids: [Solid] = []

		solids.append(.box(from: V3(near, near, 0), to: V3(far, far, 3), tone: Tone.rampart))
		for x in [near, far - 6] {
			for y in [near, far - 6] {
				solids.append(.box(from: V3(x, y, 0), to: V3(x + 6, y + 6, 7), tone: Tone.wall))
			}
		}
		solids.append(.box(from: V3(13, 13, 3), to: V3(19, 19, 9), tone: Tone.wall))

		return Model(solids)
	}
}

private extension Settlements {

	static func house(
		x: Float,
		y: Float,
		length: Float,
		width: Float,
		walls: Float,
		roof: Float,
		ridge: Axis
	) -> [Solid] {
		let from = V3(x - length / 2, y - width / 2, 0)
		let to = V3(x + length / 2, y + width / 2, walls)
		return [
			.box(from: from, to: to, tone: Tone.wall),
			.gable(
				from: V3(from.x - 0.5, from.y - 0.5, walls),
				to: V3(to.x + 0.5, to.y + 0.5, walls + roof),
				ridge: ridge,
				tone: Tone.roof
			),
		]
	}
}
