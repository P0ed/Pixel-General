import GameplayKit

public extension Map<32, Terrain> {

	/// `terrain` is the dominant terrain of the generated map: `.field` keeps
	/// the plains baseline, `.hill`/`.mountain` lift the height field so
	/// highground dominates. Campaign battles pass the contested province's
	/// strategic terrain here.
	init(size: Int, seed: Int, players: Int = 4, terrain: Terrain = .field) {
		self = Map(size: size, zero: .none)

		let size = SIMD2<Int32>(Int32(size), Int32(size))
		let seed = Int32(bitPattern: UInt32(seed & Int(UInt32.max)))
		let height = GKNoiseMap.height(size: size, seed: seed)
		let humidity = GKNoiseMap.humidity(size: size, seed: seed + 1)
		var d20 = D20(seed: UInt64(bitPattern: Int64(seed)))

		generateTerrain(
			height: height,
			humidity: humidity,
			bias: 0.25 * Float(terrain.elevationLevel)
		)
		placeRivers(height: height, d20: &d20)
		let cities = placeCities(d20: &d20, players: players)
		connectCities(cities: cities)
		shapeRoads()
	}

	private mutating func generateTerrain(height: GKNoiseMap, humidity: GKNoiseMap, bias: Float) {
		indices.forEach { xy in
			self[xy] = Terrain(
				height: height.value(at: xy.simd) + bias,
				humidity: humidity.value(at: xy.simd)
			)
		}
	}

	/// Rivers enter and leave at seed-chosen edge points and follow valleys of
	/// a low-passed height field instead of cutting straight across ridges.
	/// Rivers after the first may join an earlier one as a tributary instead
	/// of exiting at an edge; a river whose mouths or path can't be placed is
	/// skipped without cancelling the rest.
	private mutating func placeRivers(height: GKNoiseMap, d20: inout D20) {
		let riversCount = max(1, count / 288)
			+ (count >= 576 ? Int.random(in: 0 ... 1, using: &d20) : 0)
		var mouths = [] as [XY]

		(0 ..< riversCount).forEach { idx in
			guard
				let edge = Edge.allCases.randomElement(using: &d20),
				let source = riverMouth(on: edge, height: height, d20: &d20, apart: mouths)
			else { return }

			let salt = d20.next()
			let meander = GKNoiseMap.meander(
				size: SIMD2<Int32>(Int32(size), Int32(size)),
				seed: Int32(truncatingIfNeeded: salt)
			)
			var mouth = nil as XY?
			if idx == 0 || d20() >= 8 {
				let across = d20() < 14
					? edge.opposite
					: Edge.allCases.filter { e in e != edge && e != edge.opposite }
						.randomElement(using: &d20) ?? edge.opposite
				mouth = riverMouth(on: across, height: height, d20: &d20, apart: mouths, across: source)
					?? riverMouth(on: edge.opposite, height: height, d20: &d20, apart: mouths, across: source)
				guard mouth != nil else { return }
			}

			let path = shortestPath(
				from: source,
				reached: { xy in mouth.map { m in xy == m } ?? self[xy].isRiver },
				cost: { _, xy in riverStep(to: xy, mouth: mouth, height: height, meander: meander, salt: salt) }
			)
			guard let path else { return }
			path.forEach { xy in self[xy] = .water }
			mouths.append(source)
			mouth.map { m in mouths.append(m) }
		}
	}

	/// Lowest-lying of a few random candidates on `edge`, so mouths favor
	/// valleys. Mouths keep apart from other rivers' mouths, and an exit must
	/// be far enough from its `source` that the river genuinely crosses the
	/// map rather than clipping a corner.
	private func riverMouth(
		on edge: Edge,
		height: GKNoiseMap,
		d20: inout D20,
		apart mouths: [XY],
		across source: XY? = nil
	) -> XY? {
		var best = nil as XY?
		(0 ..< 3).forEach { _ in
			let t = Int.random(in: size / 6 ... size - 1 - size / 6, using: &d20)
			let p = onEdge(edge, t)
			guard
				hasNoRivers(at: p),
				mouths.allSatisfy({ xy in xy.stepDistance(to: p) >= size / 2 }),
				source.map({ xy in xy.manhattanDistance(to: p) >= size - 1 }) ?? true,
				best.map({ xy in height.value(at: p.simd) < height.value(at: xy.simd) }) ?? true
			else { return }
			best = p
		}
		return best
	}

	private func onEdge(_ edge: Edge, _ t: Int) -> XY {
		switch edge {
		case .bottom: XY(t, 0)
		case .left: XY(0, t)
		case .top: XY(t, size - 1)
		case .right: XY(size - 1, t)
		}
	}

	/// Cost of carving a river through `xy`: low-passed height squared, so
	/// macro ridges repel the river strongly while flat ground is nearly
	/// free, plus a per-river `meander` field that bends the path even where
	/// the terrain is flat, and a penalty for hugging the map border. Land
	/// next to an existing river is impassable so parallel rivers keep a gap
	/// — a tributary (`mouth == nil`) instead pays a penalty there and
	/// terminates on the first river tile it touches.
	private func riverStep(to xy: XY, mouth: XY?, height: GKNoiseMap, meander: GKNoiseMap, salt: UInt64) -> UInt16? {
		guard contains(xy) else { return nil }
		if self[xy].isRiver { return mouth == nil ? 1 : nil }
		let near = !hasNoRivers(at: xy)
		if near, mouth != nil { return nil }
		let macro = lowpass(height, at: xy)
		let local = height.value(at: xy.simd)
		let lift = max(0, min(2, 0.75 * macro + 0.25 * local + 1))
		let bend = max(0, min(2, meander.value(at: xy.simd) + 1))
		var cost = UInt16(3 + lift * lift * 16 + bend * bend * 24) + wiggle(xy, salt)
		if near { cost += 40 }
		if edge(at: xy) != nil, xy != mouth { cost += 40 }
		return cost
	}

	private func lowpass(_ height: GKNoiseMap, at xy: XY) -> Float {
		xy.s9.reduce(into: 0 as Float) { acc, p in
			acc += height.value(at: p.clamped(size).simd)
		} / 9
	}

	/// Per-tile jitter hashed from coordinates and a per-river salt — meander
	/// that doesn't depend on RNG draw order, so carving stays reproducible
	/// for a given seed.
	private func wiggle(_ xy: XY, _ salt: UInt64) -> UInt16 {
		var mix = D20(seed: salt &+ UInt64(bitPattern: Int64(xy.y &* 64 &+ xy.x)))
		return UInt16(mix.next() & 3)
	}

	private func hasNoRivers(at xy: XY) -> Bool {
		xy.n8.firstMap { xy in self[xy].isRiver ? .some(xy) : .none } == .none
	}

	private mutating func placeCities(d20: inout D20, players: Int) -> [XY] {
		let citiesCount = min(16, max(6, count / 48))

		let cols = max(1, Int(Double(citiesCount).squareRoot().rounded()))
		let rows = (citiesCount + cols - 1) / cols
		let minSpacing = max(2, size / 8)

		let margin = 1
		let span = Double(size - 2 * margin)
		let cellW = span / Double(cols)
		let cellH = span / Double(rows)

		func isCitySite(_ p: XY, _ placed: [XY]) -> Bool {
			contains(p)
			&& !self[p].isRiver
			&& !self[p].isSettlement
			&& self[p] != .water
			&& self[p] != .mountain
			&& !placed.contains { $0.stepDistance(to: p) < minSpacing }
		}

		var placed: [XY] = []
		var cities: [XY] = []

		for i in 0 ..< citiesCount {
			let gx = i % cols
			let gy = i / cols
			let jx = Double.random(in: 0.15 ... 0.85, using: &d20)
			let jy = Double.random(in: 0.15 ... 0.85, using: &d20)
			var p = XY(
				margin + Int((Double(gx) + jx) * cellW),
				margin + Int((Double(gy) + jy) * cellH)
			).clamped(size)

			if !isCitySite(p, placed),
			   let alt = p.n36.firstMap({ isCitySite($0, placed) ? $0 : nil }) {
				p = alt
			}
			guard isCitySite(p, placed) else { continue }

			self[p] = .city
			placed.append(p)
			cities.append(p)

			if cities.count % 3 == 0 { placeAirfield(near: p, placed: &placed, d20: &d20) }
		}

		var airfieldCount = placed.count - cities.count
		for city in cities where airfieldCount < players {
			let hasAirfield = city.n4.contains { ap in
				contains(ap) && self[ap] == .airfield
			}
			if !hasAirfield, placeAirfield(near: city, placed: &placed, d20: &d20) {
				airfieldCount += 1
			}
		}

		return placed
	}

	@discardableResult
	private mutating func placeAirfield(near city: XY, placed: inout [XY], d20: inout D20) -> Bool {
		guard let ap = city.n4
			.compactMap({ p in contains(p) && self[p] == .field ? p : nil })
			.randomElement(using: &d20)
		else { return false }
		self[ap] = .airfield
		placed.append(ap)
		return true
	}

	private mutating func connectCities(cities: [XY]) {
		let cities = cities.filter { xy in self[xy] == .city }
		guard cities.count > 1 else { return }

		var connected = [] as [[XY]]

		let isConnected = { xy in
			connected.contains { $0.contains(xy) }
		}
		cities.forEach { xy in
			if !isConnected(xy) {
				let nxt = cities
					.filter { ij in ij != xy && !isConnected(ij) }
					.min(by: xy.manhattanComparator)
				if let nxt, connect(xy, nxt) {
					connected.append([xy, nxt])
				}
			}
		}

		guard connected.count > 1 else { return }

		for i in connected.indices {
			let cs = connected[i]
			cities
				.filter { c in !cs.contains(c) }
				.min(by: XY((cs[0].x + cs[1].x) / 2, (cs[0].y + cs[1].y) / 2).manhattanComparator)
				.map { c in
					let csm = cs.min(by: c.manhattanComparator)
					if let csm, (c - csm).manhattan < 22, connect(c, csm) {
						connected.firstIndex { cs in cs.contains(c) }
							.map { j in
								let ds = connected[j]
								connected[j].append(contentsOf: cs)
								connected[i].append(contentsOf: ds)
							}
						?? connected[i].append(c)
					}
				}
		}
	}

	mutating func shapeRoads() {
		var neighbors = [false, false, false, false] as [4 of Bool]
		for xy in indices {
			if self[xy].hasRoad, !self[xy].isBridge, !self[xy].isSettlement {
				let n4 = xy.n4
				for i in n4.indices {
					neighbors[i] = self[n4[i]].hasRoad
				}
				let r = Self.road(neighbors)
				if r != .none { self[xy] = r }
			} else if self[xy].isBridge {
				let n4 = xy.n4
				if self[n4[0]].isRiver, self[n4[2]].isRiver {
					self[xy] = .bridgeSN
				} else if self[n4[1]].isRiver, self[n4[3]].isRiver {
					self[xy] = .bridgeWE
				}
			}
		}
	}

	private static func road(_ neighbors: [4 of Bool]) -> Terrain {
		// East, North, West, South
		switch (neighbors[0], neighbors[1], neighbors[2], neighbors[3]) {
		case (false, true, false, true): .roadSN
		case (true, false, true, false): .roadWE
		case (true, true, false, false): .roadNE
		case (true, false, false, true): .roadSE
		case (false, true, true, false): .roadNW
		case (false, false, true, true): .roadSW
		case (false, true, true, true): .villageE
		case (true, false, true, true): .villageN
		case (true, true, false, true): .villageW
		case (true, true, true, false): .villageS
		case (true, true, true, true): .roadX
		default: .none
		}
	}

	private func bridgableRiver(at r: XY, from l: XY) -> Bool {
		let n4 = r.n4
		return self[r].isRiver
		&& self[l].isBridgable && self[r + r + r - l - l].isBridgable
		&& (
			self[n4[0]].isRiver && self[n4[2]].isRiver
			|| self[n4[1]].isRiver && self[n4[3]].isRiver
		)
	}

	/// Cost of stepping onto `to` from `l`, or `nil` if impassable. Roads and
	/// buildings are nearly free, open ground is cheap, and forest/hills cost
	/// progressively more so a route only carves through them when there's no
	/// gentler way around. Rivers are passable solely where a bridge fits.
	private func stepCost(to: XY, from l: XY) -> UInt16? {
		let t = self[to]
		if t.hasRoad { return 1 }
		switch t {
		case .field: return 4
		case .forest: return 6
		case .hill: return 10
		case .forestHill: return 12
		default: return bridgableRiver(at: to, from: l) ? 8 : nil
		}
	}

	private mutating func connect(_ start: XY, _ end: XY) -> Bool {
		let path = shortestPath(
			from: start,
			reached: { xy in xy == end },
			cost: { from, to in stepCost(to: to, from: from) }
		)
		guard let path else { return false }
		path.forEach { xy in
			if !self[xy].isSettlement {
				self[xy] = self[xy].isRiver || self[xy].isBridge ? .bridgeWE : .roadX
			}
		}
		return true
	}

	/// Dijkstra over 4-neighbors from `start` until a tile satisfying
	/// `reached` is finalized, following `cost(from, to)` (`nil` =
	/// impassable). Returns the path including both endpoints. Lazy deletion
	/// pushes one heap entry per relaxation — at most the grid's directed
	/// edge count, 3969 for 32×32 — so 4096 never overflows.
	private func shortestPath(
		from start: XY,
		reached: (XY) -> Bool,
		cost: (XY, XY) -> UInt16?
	) -> [XY]? {
		var dist = Map<32, UInt16>(size: size, zero: .max)
		var prev = Map<32, UInt16>(size: size, zero: 0)
		dist[start] = 0

		var heapD = CArray<4096, UInt16>(head: 0, tail: 0)
		var heapL = CArray<4096, XY>(head: start, tail: .zero)

		func siftUp(_ from: Int) {
			var i = from
			while i > 0 {
				let parent = (i - 1) / 2
				if heapD[parent] <= heapD[i] { break }
				heapD.swapAt(parent, i)
				heapL.swapAt(parent, i)
				i = parent
			}
		}
		func siftDown(_ from: Int) {
			var i = from
			while true {
				let l = 2 * i + 1, r = 2 * i + 2
				var m = i
				if l < heapD.count, heapD[l] < heapD[m] { m = l }
				if r < heapD.count, heapD[r] < heapD[m] { m = r }
				if m == i { break }
				heapD.swapAt(m, i)
				heapL.swapAt(m, i)
				i = m
			}
		}

		while !heapD.isEmpty {
			let topD = heapD[0]
			let topL = heapL[0]
			let lastD = heapD.removeLast()
			let lastL = heapL.removeLast()
			if !heapD.isEmpty {
				heapD[0] = lastD
				heapL[0] = lastL
				siftDown(0)
			}
			if topD != dist[topL] { continue }
			if reached(topL) {
				var path = [topL]
				var head = topL
				while head != start {
					let packed = prev[head]
					guard packed != 0 else { break }
					let idx = Int(packed) - 1
					head = XY(idx % size, idx / size)
					path.append(head)
				}
				return path
			}

			let n4 = topL.n4
			for i in n4.indices {
				let nb = n4[i]
				guard contains(nb), let w = cost(topL, nb) else { continue }
				let nd = topD &+ w
				if nd < dist[nb] {
					dist[nb] = nd
					prev[nb] = UInt16(topL.y * size + topL.x + 1)
					heapD.add(nd)
					heapL.add(nb)
					siftUp(heapD.count - 1)
				}
			}
		}
		return nil
	}
}

public extension Edge {

	var opposite: Edge {
		switch self {
		case .bottom: .top
		case .left: .right
		case .top: .bottom
		case .right: .left
		}
	}
}

public extension Map {

	func edge(at xy: XY) -> Edge? {
		if xy.y == 0 {
			.bottom
		} else if xy.x == 0 {
			.left
		} else if xy.y == size - 1 {
			.top
		} else if xy.x == size - 1 {
			.right
		} else {
			.none
		}
	}
}

public extension XY {

	var simd: SIMD2<Int32> {
		SIMD2<Int32>(Int32(x), Int32(y))
	}
}

extension Terrain {

	init(height: Float, humidity: Float) {
		self = switch height {
		case -0.5 ..< 0.3: humidity > 0.5 ? .forest : .field
		case 0.3 ..< 0.7: humidity > 0.5 ? .forestHill : .hill
		case 0.7 ..< 0.85: .hill
		case 0.85...: .mountain
		default: .field
		}
	}
}

extension GKNoiseMap {

	private static func map(size: SIMD2<Int32>, source: GKNoiseSource) -> GKNoiseMap {
		GKNoiseMap(
			GKNoise(source),
			size: .one,
			origin: .zero,
			sampleCount: size,
			seamless: false
		)
	}

	static func height(size: SIMD2<Int32>, seed: Int32) -> GKNoiseMap {
		.map(size: size, source: GKPerlinNoiseSource(
			frequency: 12.0,
			octaveCount: 6,
			persistence: 0.47,
			lacunarity: 1.5,
			seed: seed
		))
	}

	static func meander(size: SIMD2<Int32>, seed: Int32) -> GKNoiseMap {
		.map(size: size, source: GKPerlinNoiseSource(
			frequency: 5.0,
			octaveCount: 2,
			persistence: 0.5,
			lacunarity: 2.0,
			seed: seed
		))
	}

	static func humidity(size: SIMD2<Int32>, seed: Int32) -> GKNoiseMap {
		.map(size: size, source: GKVoronoiNoiseSource(
			frequency: 6.8,
			displacement: 1.0,
			distanceEnabled: false,
			seed: seed
		))
	}
}
