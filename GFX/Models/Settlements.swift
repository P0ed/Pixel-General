/// Settlement art that fits inside the projected tile frame.
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
		// Leave room for the roofs to project towards the back of the tile.
		let near: Float = 12
		let far: Float = 39
		let centers = [(near, near), (far, near), (near, far), (far, far)]
		let solids = zip(blocks, centers).flatMap { block, center in
			buildings(block, x: center.0, y: center.1)
		}
		return Roads.road(Direction.allCases) + Model(solids)
	}

	/// Runway with dashed centreline, a control tower and two hangars set back from it.
	public static var airfield: Model {
		let strip = Solid.box(from: V3(1.5, 28.5, 0), to: V3(46.5, 39, 0), tone: Roads.Tone.bed)
		let apron = Solid.box(from: V3(19.5, 16.5, 0), to: V3(28.5, 28.5, 0), tone: Roads.Tone.bed)
		let solids = [
			strip, apron,
			.box(from: V3(21.75, 11.25, 0), to: V3(26.25, 15.75, 6), tone: Tone.wall),
			.box(from: V3(21, 10.5, 6), to: V3(27, 16.5, 8.25), tone: Tone.roof),
		] + hangar(x: 12, y: 15) + hangar(x: 36, y: 15)

		return Model(solids, lines: [
			Line(from: V3(4.5, 33.75, 0), to: V3(43.5, 33.75, 0), tone: 236, dash: 4.5),
		])
	}

	public static var fort: Model { fort(variant: .first) }

	public static var portWater: Model {
		Model(
			portStrip(5..<9, 1..<16),
			portStrip(1..<14, 11..<13),
			portStrip(4..<11, 13..<16),
		)
	}

	public static var port: Model {
		let quays = [
			portStrip(3..<5, 1..<11, height: 1, tone: Roads.Tone.bed),
			portStrip(9..<11, 1..<11, height: 1, tone: Roads.Tone.bed),
			portStrip(4..<5, 13..<16, height: 1, tone: Roads.Tone.bed),
			portStrip(10..<11, 13..<16, height: 1, tone: Roads.Tone.bed),
		]
		let warehouses = house(x: 8, y: 18, length: 4.5, width: 13, walls: 3, roof: 2, ridge: .y)
			+ house(x: 39, y: 23, length: 6, width: 12, walls: 3, roof: 2, ridge: .y)
		return Model(quays + warehouses + buildings(.apartments, x: 38, y: 11))
	}

	public static func fort(variant: Tiles.Variant) -> Model {
		let layout = switch variant {
		case .first:
			"""
			.....#.....
			.....#.....
			.#########.
			..#.....#..
			..#.....#..		
			#########..
			.....#.....
			.....#.....
			.....#.....
			..########.
			...........
			"""
		case .second:
			"""
			...........
			.####......
			....######.
			.....#...#.
			.....#...#.
			.#####...#.
			##...######
			.#.........
			.########..
			.....#.....
			.....#.....
			"""
		case .third:
			"""
			.....#.....
			.....#.....
			.#...#..#..
			.#...#..#..
			.#####..#..
			.#...####..
			.#...#..#..
			.#####..#..
			.....#..#..
			.....#..#..
			.....#.....
			"""
		case .fourth:
			"""
			...........
			...####....
			...#..####.
			...#....#..
			...#....#..
			#####.#####
			....#...#..
			....#...#..
			....##..#..
			.....#####.
			.....#.....
			"""
		}
		let cells = layout.split(separator: "\n").map(Array.init)
		let cellSize: Float = Volume.footprint / Float(cells.count)
		let boundaries = [0.75] + (1 ..< cells.count).map { Float($0) * cellSize } + [Volume.footprint - 0.75]
		var solids: [Solid] = []

		for (row, cellsInRow) in cells.enumerated() {
			for column in cellsInRow.indices where cellsInRow[column] == "#" {
				let from = V3(boundaries[column], boundaries[row], 0)
				let to = V3(boundaries[column + 1], boundaries[row + 1], 0)
				let center = (from + to) * 0.5
				let halfSize = (to - from) * 0.5
				solids.append(.box(from: from, to: to, tone: 99))

				// The earth slopes up toward the cut and leaves the passage open at joins.
				for turn in Turn.allCases {
					let offset = turn.apply(V3(0, -1, 0))
					let neighborRow = row + Int(offset.y)
					let neighborColumn = column + Int(offset.x)
					guard cells.indices.contains(neighborRow), cells[neighborRow].indices.contains(neighborColumn),
						cells[neighborRow][neighborColumn] != "#" else { continue }
					let half = turn.apply(halfSize)
					let width = abs(half.x)
					let depth = abs(half.y)
					let bank = Solid.wedge(
						from: center + V3(-width, -depth - 1.5, 0),
						to: center + V3(width, -depth, 1),
						rising: .yPlus,
						tone: 180
					)
					solids.append(bank.rotated(turn, about: center))
				}
			}
		}

		for i in solids.indices { solids[i].outline = .connectedDecal() }
		return Model(solids)
	}
}

private extension Settlements {

	static func portStrip(_ columns: Range<Int>, _ rows: Range<Int>, height: Float = 0, tone: UInt8 = .max) -> Solid {
		let width = Volume.footprint / 16
		let depth = Volume.footprint / 16
		return .box(
			from: V3(Float(columns.lowerBound) * width + 0.5, Float(rows.lowerBound) * depth - 0.5, 0),
			to: V3(Float(columns.upperBound) * width + 0.5, min(Float(rows.upperBound) * depth - 0.5, Volume.footprint - height), height),
			tone: tone
		)
	}

	enum CityBlock {
		case houses, apartments, market
	}

	static func buildings(_ block: CityBlock, x: Float, y: Float) -> [Solid] {
		switch block {
		case .houses:
			// The inner house sits lower so its roof leaves the crossroad visible.
			let outward: Float = x < Volume.footprint / 2 ? -1 : 1
			return house(x: x + outward * 2.25, y: y, length: 4.5, width: 6, walls: 3, roof: 3, ridge: .y)
				+ house(x: x - outward * 3.75, y: y, length: 3.75, width: 6, walls: 3, roof: 2.25, ridge: .x)
		case .apartments:
			return [
				.box(from: V3(x - 3, y - 3, 0), to: V3(x + 3, y + 3, 5.25), tone: Tone.wall),
				.box(from: V3(x - 3.75, y - 3.75, 5.25), to: V3(x + 3.75, y + 3.75, 6), tone: Tone.roof),
			]
		case .market:
			return house(x: x, y: y - 3.75, length: 9, width: 3.75, walls: 3, roof: 2.25, ridge: .x)
				+ house(x: x, y: y + 3.75, length: 6.75, width: 3.75, walls: 2.25, roof: 1.5, ridge: .x)
		}
	}

	/// A wide, low shed beside the control tower.
	static func hangar(x: Float, y: Float) -> [Solid] {
		[
			.box(from: V3(x - 4.5, y - 3, 0), to: V3(x + 4.5, y + 3, 2.25), tone: Tone.wall),
			.gable(from: V3(x - 5.25, y - 3.75, 2.25), to: V3(x + 5.25, y + 3.75, 5.25), ridge: .x, tone: Tone.roof),
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
