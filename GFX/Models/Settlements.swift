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
		for (column, x) in ([6, 13.5, 34.5, 42] as [Float]).enumerated() {
			for y: Float in [9, 39] {
				let outer = column == 0 || column == 3
				solids += house(
					x: x,
					y: y,
					length: outer ? 6 : 4.5,
					width: 9,
					walls: outer ? 4.5 : 3.75,
					roof: outer ? 4.5 : 3,
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
			house(x: 9, y: 11.25, length: 10.5, width: 9, walls: 4.5, roof: 3.75, ridge: .x)
				+ house(x: 9, y: 36.75, length: 9, width: 9, walls: 4.5, roof: 3.75, ridge: .y)
				+ house(x: 39, y: 39, length: 9, width: 9, walls: 4.5, roof: 3.75, ridge: .x)
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
		let strip = Solid.box(from: V3(1.5, 28.5, 0), to: V3(46.5, 39, 0), tone: Roads.Tone.bed)
		let apron = Solid.box(from: V3(19.5, 19.5, 0), to: V3(28.5, 28.5, 0), tone: Roads.Tone.bed)

		var solids = [strip, apron]
		solids += [
			.box(from: V3(21, 9, 0), to: V3(27, 15, 9), tone: Tone.wall),
			.box(from: V3(19.5, 7.5, 9), to: V3(28.5, 16.5, 12.75), tone: Settlements.Tone.roof),
		]
		solids += hangar(x: 7.5, y: 13.5) + hangar(x: 36, y: 12)

		return Model(solids, lines: [
			Line(from: V3(4.5, 33.75, 0), to: V3(43.5, 33.75, 0), tone: Roads.Tone.mark, dash: 4.5),
		])
	}

	public static var fort: Model {
		let inset: Float = 7.5
		let side = Volume.footprint
		let near = inset
		let far = side - inset
		var solids: [Solid] = []

		solids.append(.box(from: V3(near, near, 0), to: V3(far, far, 4.5), tone: Tone.rampart))
		for x in [near, far - 9] {
			for y in [near, far - 9] {
				solids.append(.box(from: V3(x, y, 0), to: V3(x + 9, y + 9, 10.5), tone: Tone.wall))
			}
		}
		solids.append(.box(from: V3(19.5, 19.5, 4.5), to: V3(28.5, 28.5, 13.5), tone: Tone.wall))

		return Model(solids)
	}
}

private extension Settlements {

	/// A wide, low shed: half the height of a house so it reads as a hangar next to one.
	static func hangar(x: Float, y: Float) -> [Solid] {
		[
			.box(from: V3(x - 6, y - 4.5, 0), to: V3(x + 6, y + 4.5, 3), tone: Tone.wall),
			.gable(from: V3(x - 6.75, y - 5.25, 3), to: V3(x + 6.75, y + 5.25, 7.5), ridge: .x, tone: Tone.roof),
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
				from: V3(from.x - 0.75, from.y - 0.75, walls),
				to: V3(to.x + 0.75, to.y + 0.75, walls + roof),
				ridge: ridge,
				tone: Tone.roof
			),
		]
	}
}
