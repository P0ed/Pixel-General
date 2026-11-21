/// Buildings drawn on a tile: rendered with `Renderer.tile`, never leaving the footprint.
public enum Settlements {

	public enum Tone {
		public static let wall: UInt8 = 235
		public static let roof: UInt8 = 185
	}

	public static var city: Model { city(variant: .first) }

	public static func city(variant: Tiles.Variant) -> Model {
		let blocks: [CityBlock] = switch variant {
		case .first: [.houses, .houses, .houses, .houses]
		case .second: [.apartments, .apartments, .market, .apartments]
		case .third: [.market, .houses, .houses, .market]
		case .fourth: [.houses, .market, .apartments, .houses]
		}
		let centers: [(Float, Float)] = [(9, 9), (39, 9), (9, 39), (39, 39)]
		let solids = zip(blocks, centers).flatMap { block, center in
			buildings(block, x: center.0, y: center.1)
		}
		return Roads.road(Direction.allCases) + Model(solids)
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

	public static var fort: Model { fort(variant: .first) }

	public static func fort(variant: Tiles.Variant) -> Model {
		let layout = switch variant {
		case .first:
			"""
			......
			###...
			..#...
			..###.
			....##
			......
			"""
		case .second:
			"""
			...#..
			...#..
			.###..
			.#....
			.####.
			......
			"""
		case .third:
			"""
			..#...
			..#...
			####..
			...#..
			...###
			......
			"""
		case .fourth:
			"""
			......
			#####.
			.#....
			.#....
			.#####
			......
			"""
		}
		let cells = layout.split(separator: "\n").map(Array.init)
		let cellSize: Float = 6
		let half = cellSize / 2
		let firstCenter = cellSize + half
		let corner = V3(half, half, 0)
		var solids: [Solid] = []

		for (row, cellsInRow) in cells.enumerated() {
			for column in cellsInRow.indices where cellsInRow[column] == "#" {
				let center = V3(firstCenter + Float(column) * cellSize, firstCenter + Float(row) * cellSize, 0)
				solids.append(.box(from: center - corner, to: center + corner, tone: 99))

				// The earth slopes up toward the cut and leaves the passage open at joins.
				let bank = Solid.wedge(
					from: center + V3(-half, -half - 3, 0),
					to: center + V3(half, -half, 3),
					rising: .yPlus,
					tone: 180
				)
				for turn in Turn.allCases {
					let offset = turn.apply(V3(0, -1, 0))
					let neighborRow = row + Int(offset.y)
					let neighborColumn = column + Int(offset.x)
					if cells.indices.contains(neighborRow), cells[neighborRow].indices.contains(neighborColumn),
						cells[neighborRow][neighborColumn] == "#" { continue }
					solids.append(bank.rotated(turn, about: center))
				}
			}
		}

		return Model(solids)
	}
}

private extension Settlements {

	enum CityBlock {
		case houses, apartments, market
	}

	static func buildings(_ block: CityBlock, x: Float, y: Float) -> [Solid] {
		switch block {
		case .houses:
			// The inner house sits lower so its roof leaves the crossroad visible.
			let outward: Float = x < Volume.footprint / 2 ? -1 : 1
			return house(x: x + outward * 3, y: y, length: 6, width: 9, walls: 4.5, roof: 4.5, ridge: .y)
				+ house(x: x - outward * 4.5, y: y, length: 4.5, width: 9, walls: 3.75, roof: 3, ridge: .x)
		case .apartments:
			return [
				.box(from: V3(x - 4.5, y - 4.5, 0), to: V3(x + 4.5, y + 4.5, 7.5), tone: Tone.wall),
				.box(from: V3(x - 5.25, y - 5.25, 7.5), to: V3(x + 5.25, y + 5.25, 8.25), tone: Tone.roof),
			]
		case .market:
			return house(x: x, y: y - 4.5, length: 12, width: 4.5, walls: 3.75, roof: 3, ridge: .x)
				+ house(x: x, y: y + 4.5, length: 9, width: 4.5, walls: 3, roof: 2.25, ridge: .x)
		}
	}

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
