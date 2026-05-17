import GameplayKit

extension Map<Terrain> {

	init(size: Int, seed: Int) {
		self = Map(size: size, zero: .none)

		let size = SIMD2<Int32>(Int32(size), Int32(size))
		let seed = Int32(bitPattern: UInt32(seed & Int(UInt32.max)))
		let height = GKNoiseMap.height(size: size, seed: seed)
		let humidity = GKNoiseMap.humidity(size: size, seed: seed + 1)
		var d20 = D20(seed: UInt64(bitPattern: Int64(seed)))

		generateTerrain(height: height, humidity: humidity)
		placeRivers(height: height)
		let cities = placeCities(d20: &d20)
		connectCities(cities: cities)
		shapeRoads()
		shapeRivers()
	}

	private mutating func generateTerrain(height: GKNoiseMap, humidity: GKNoiseMap) {
		indices.forEach { xy in
			self[xy] = Terrain(
				height: height.value(at: xy.simd),
				humidity: humidity.value(at: xy.simd)
			)
		}
	}

	private mutating func placeRivers(height: GKNoiseMap) {
		let riversCount = max(1, count / 288)

		let setups: [(XY, XY)] = riversCount == 1
		? [
			(XY(0, size / 3), XY(size - 1, size * 2 / 3))
		]
		: [
			(XY(0, size * 2 / 3), XY(size * 2 / 3, size - 1)),
			(XY(size / 3, 0), XY(size - 1, size / 3)),
			(XY(0, size / 3), XY(size - 1, size * 2 / 3)),
		]

		(0 ..< riversCount).forEach { idx in
			let (start, end) = setups[idx]

			var front = CArray<1024, XY>(head: start, tail: .zero)
			var next = CArray<1024, XY>(tail: .zero)
			var pressure = Map<UInt16>(size: size, zero: 0)
			pressure[start] = 1

			while true {
				next.erase()
				front.forEach { _, xy in
					xy.n4.forEach { [p = pressure[xy]] xy in
						let nh = UInt16(height.value(at: xy.simd) + 1.0)
						let dh = xy != end && edge(at: xy) != nil ? 2 : 0 as UInt16
						let h = (nh * 2 + dh) * 3
						if contains(xy), pressure[xy] == 0, p > h, hasNoRivers(at: xy) {
							pressure[xy] = 1
							next.add(xy)
						}
					}
				}
				if next.contains(end) { break }
				front.forEach { _, xy in pressure[xy] += 1 }
				next.forEach { _, xy in front.add(xy) }
				if pressure[start] >= 1024 { return }
			}
			var head = end
			self[end] = .river00
			while head != start {
				let xy = head.n4.compactMap { xy in
					contains(xy) && self[xy] != .river00 ? xy : nil
				}
				.max { a, b in pressure[a] < pressure[b] }

				if let xy {
					head = xy
					self[xy] = .river00
				} else {
					break
				}
			}
		}
	}

	private func hasNoRivers(at xy: XY) -> Bool {
		xy.n8.firstMap { xy in self[xy].isRiver ? .some(xy) : .none } == .none
	}

	private mutating func placeCities(d20: inout D20) -> [XY] {
		let citiesCount = min(16, max(3, count / 64))

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
			&& !self[p].isBuilding
			&& self[p] != .water
			&& self[p] != .mountain
			&& !placed.contains { $0.stepDistance(to: p) < minSpacing }
		}

		return (0 ..< citiesCount).reduce(into: []) { placed, i in
			let gx = i % cols
			let gy = i / cols
			let jx = Double.random(in: 0.15 ... 0.85, using: &d20)
			let jy = Double.random(in: 0.15 ... 0.85, using: &d20)
			var p = XY(
				margin + Int((Double(gx) + jx) * cellW),
				margin + Int((Double(gy) + jy) * cellH)
			).clamped(size)

			if !isCitySite(p, placed), let alt = p.circle(6).first(where: { isCitySite($0, placed) }) {
				p = alt
			}
			guard isCitySite(p, placed) else { return }

			self[p] = .city
			placed.append(p)

			if d20() < 7, let ap = p.n4
				.compactMap({ p in contains(p) && self[p] == .field ? p : nil })
				.randomElement(using: &d20)
			{
				self[ap] = .airfield
				placed.append(ap)
			}
		}
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

	mutating func shapeRivers() {
		for xy in indices where self[xy] == .river00 {
			let n4 = xy.n4
			self[xy] = Self.river([
				self[n4[2]].isRiver || self[n4[2]].isBridge,
				self[n4[1]].isRiver || self[n4[1]].isBridge
			])
		}
	}

	mutating func shapeRoads() {
		var neighbors = [false, false, false, false] as [4 of Bool]
		for xy in indices {
			if self[xy].isRoad, !self[xy].isBridge {
				let n4 = xy.n4
				for i in n4.indices {
					neighbors[i] = self[n4[i]].isRoad || self[n4[i]].isBuilding
				}
				let r = Self.road(neighbors)
				if r != .none { self[xy] = r }
			} else if self[xy].isBridge {
				let n4 = xy.n4
				if self[n4[0]].isRiver, self[n4[2]].isRiver {
					self[xy] = .bridge01
				} else if self[n4[1]].isRiver, self[n4[3]].isRiver {
					self[xy] = .bridge10
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
		case (true, true, true, false): .roadNWE
		case (true, true, false, true): .roadSEN
		case (false, true, true, true): .roadSWN
		case (true, false, true, true): .roadSWE
		case (true, true, true, true): .roadNWSE
		default: .none
		}
	}

	private static func river(_ neighbors: [2 of Bool]) -> Terrain {
		// West, North
		switch (neighbors[0], neighbors[1]) {
		case (true, true): .river00
		case (false, true): .river10
		case (true, false): .river01
		case (false, false): .river11
		}
	}

	private func crossesRiver(_ start: XY, _ end: XY) -> Bool {
		start.line(to: end).contains { xy in self[xy].isRiver }
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
		if t.isBuilding || t.isRoad { return 1 }
		switch t {
		case .field: return 4
		case .forest: return 6
		case .hill: return 10
		case .forestHill: return 12
		default: return bridgableRiver(at: to, from: l) ? 8 : nil
		}
	}

	private mutating func connect(_ start: XY, _ end: XY) -> Bool {
		var dist = Map<UInt16>(size: size, zero: .max)
		var prev = Map<UInt16>(size: size, zero: 0)
		dist[start] = 0

		var heapD = CArray<1024, UInt16>(head: 0, tail: 0)
		var heapL = CArray<1024, XY>(head: start, tail: .zero)

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
			if topL == end { break }

			let n4 = topL.n4
			for i in n4.indices {
				let nb = n4[i]
				guard contains(nb), let w = stepCost(to: nb, from: topL) else { continue }
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

		guard dist[end] != .max else { return false }

		var head = end
		while true {
			if !self[head].isBuilding {
				self[head] = self[head].isRiver || self[head].isBridge ? .bridge01 : .roadNWSE
			}
			if head == start { break }
			let packed = prev[head]
			guard packed != 0 else { break }
			let idx = Int(packed) - 1
			head = XY(idx % size, idx / size)
		}
		return true
	}
}

extension Edge {

	var opposite: Edge {
		switch self {
		case .bottom: .top
		case .left: .right
		case .top: .bottom
		case .right: .left
		}
	}
}

extension Map {

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

extension XY {

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
		case 0.85 ... 1.0: .mountain
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

	static func humidity(size: SIMD2<Int32>, seed: Int32) -> GKNoiseMap {
		.map(size: size, source: GKVoronoiNoiseSource(
			frequency: 6.8,
			displacement: 1.0,
			distanceEnabled: false,
			seed: seed
		))
	}
}
