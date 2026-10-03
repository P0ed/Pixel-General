/// Buildings drawn on a tile: rendered with `Renderer.tile`, never leaving the footprint.
public enum Settlements {

	public enum Tone {
		public static let wall: UInt8 = 235
		public static let roof: UInt8 = 185
		public static let rampart: UInt8 = 215
	}

	public static var city: Model {
		// Two houses per corner block leave the central crossroad open. The inner
		// houses are lower so their roofs cannot hide the road in the isometric view.
		var solids: [Solid] = []
		for (column, x) in ([4, 9, 23, 28] as [Float]).enumerated() {
			for y: Float in [6, 26] {
				let outer = column == 0 || column == 3
				solids += house(
					x: x,
					y: y,
					length: outer ? 4 : 3,
					width: 6,
					walls: outer ? 3 : 2.5,
					roof: outer ? 3 : 2,
					ridge: outer ? .y : .x
				)
			}
		}

		return Roads.road(Direction.allCases) + Model(solids)
	}

	/// A T junction with houses clear of its carriageway. `facing` names the missing
	/// road arm, matching villageE/N/W/S in the map generator.
	public static func village(facing: Direction) -> Model {
		let base = Roads.road([.yMinus, .yPlus, .xPlus]) + Model(
			house(x: 6, y: 7.5, length: 7, width: 6, walls: 3, roof: 2.5, ridge: .x)
				+ house(x: 6, y: 24.5, length: 6, width: 6, walls: 3, roof: 2.5, ridge: .y)
				+ house(x: 26, y: 26, length: 6, width: 6, walls: 3, roof: 2.5, ridge: .x)
		)

		switch facing {
		case .xMinus: return base
		case .yMinus: return base.rotated(.left)
		case .xPlus: return base.rotated(.half)
		case .yPlus: return base.rotated(.right)
		}
	}

	/// Runway with dashed centreline, a control tower and two hangars set back from it.
	public static var airfield: Model {
		let strip = Solid.box(from: V3(1, 19, 0), to: V3(31, 26, 0), tone: Roads.Tone.bed)
		let apron = Solid.box(from: V3(13, 13, 0), to: V3(19, 19, 0), tone: Roads.Tone.bed)

		var solids = [strip, apron]
		solids += [
			.box(from: V3(14, 6, 0), to: V3(18, 10, 6), tone: Tone.wall),
			.box(from: V3(13, 5, 6), to: V3(19, 11, 8.5), tone: Settlements.Tone.roof),
		]
		solids += hangar(x: 5, y: 9) + hangar(x: 24, y: 8)

		return Model(solids, lines: [
			Line(from: V3(3, 22.5, 0), to: V3(29, 22.5, 0), tone: Roads.Tone.mark, dash: 3),
		])
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

	/// A wide, low shed: half the height of a house so it reads as a hangar next to one.
	static func hangar(x: Float, y: Float) -> [Solid] {
		[
			.box(from: V3(x - 4, y - 3, 0), to: V3(x + 4, y + 3, 2), tone: Tone.wall),
			.gable(from: V3(x - 4.5, y - 3.5, 2), to: V3(x + 4.5, y + 3.5, 5), ridge: .x, tone: Tone.roof),
		]
	}

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
