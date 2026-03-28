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
		shapeRivers()
		shapeRoads()
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

			var front = [start]
			var pressure = Map<UInt16>(size: size, zero: 0)
			pressure[start] = 1

			while true {
				let nf: [XY] = front.flatMap { xy in
					xy.n4.compactMap { [p = pressure[xy]] xy in
						let nh = UInt16(height.value(at: xy.simd) + 1.0)
						let dh = xy != end && edge(at: xy) != nil ? 2 : 0 as UInt16
						let h = (nh * 2 + dh) * 3
						if contains(xy), pressure[xy] == 0, p > h, hasNoRivers(at: xy) {
							pressure[xy] = 1
							return xy
						} else {
							return nil
						}
					}
				}
				if nf.contains(end) { break }
				front.forEach { xy in pressure[xy] += 1 }
				front += nf
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
		let citiesCount = min(32, size * size / 64)
		let div = size / 8
		let dw = (size - 4) / (div - 1) - 1
		let div2 = citiesCount / div + (citiesCount % div == 0 ? 0 : 1)
		let dh = (size - 2) / (div2 - 1) - 1
		print("citiesCount:", citiesCount, "div:", div, div2, dw, dh)

		return (0 ..< citiesCount).reduce(into: []) { xys, i in
			let x = i % div
			let y = (i / div)
			let p = modifying(
				XY(1 + dw * x + 2 * (y & 1), 1 + dh * y)
			) { p in
				if self[p].isRiver, let x = p.n8.firstMap({ p in !self[p].isRiver ? p : nil }) {
					p = x
				}
			}
			let ap = i % 3 != 0 ? nil : p.n4.compactMap { p in !self[p].isRiver ? p : nil }
				.randomElement(using: &d20)
			self[p] = .city
			xys.append(p)
			if let ap {
				self[ap] = .airfield
				xys.append(ap)
			}
		}
	}

	private mutating func connectCities(cities: [XY]) {
		let cities = cities.filter { xy in self[xy] == .city }
		guard cities.count > 1 else { return }

		var connected = [] as Set<XY>

		let isConnected = { xy in connected.contains(xy) }
		cities.forEach { xy in
			if isConnected(xy) {

			} else {
				let nxt = cities
					.filter { ij in ij != xy && !isConnected(ij) }
					.min { a, b in (a - xy).manhattan < (b - xy).manhattan }
				if let nxt, connect(xy, nxt) {
					connected.insert(xy)
					connected.insert(nxt)
				}
			}
		}
	}

	private mutating func shapeRivers() {
		var neighbors = [false, false] as [2 of Bool]
		for xy in indices where self[xy] == .river00 {
			let n4 = xy.n4
			neighbors[0] = self[n4[2]].isRiver
			neighbors[1] = self[n4[1]].isRiver
			self[xy] = Self.river(neighbors)
		}
	}

	private mutating func shapeRoads() {
		var neighbors = [false, false, false, false] as [4 of Bool]
		for xy in indices where self[xy] == .roadNWSE {
			let n4 = xy.n4
			for i in n4.indices {
				neighbors[i] = self[n4[i]].isRoad || self[n4[i]].isBuilding
			}
			self[xy] = Self.road(neighbors)
		}
	}

	private static func road(_ neighbors: [4 of Bool]) -> Terrain {
		// East, North, West, South
		switch (neighbors[0], neighbors[1], neighbors[2], neighbors[3]) {
		case (true, true, false, false): .roadNE
		case (true, false, true, false): .roadWE
		case (true, false, false, true): .roadSE
		case (false, true, true, false): .roadNW
		case (false, false, true, true): .roadSW
		case (false, true, false, true): .roadSN
		case (true, true, true, false): .roadNWE
		case (true, true, false, true): .roadSEN
		case (false, true, true, true): .roadSWN
		case (true, false, true, true): .roadSWE
		default: .roadNWSE
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

	private mutating func connect(_ start: XY, _ end: XY) -> Bool {
		print("connecting \(start) \(end)")
		var front = [start]
		var map = Map<UInt16>(size: size, zero: 0)
		map[start] = 1

		while true {
			let nf: [XY] = front.flatMap { xy in
				xy.n4.compactMap { [p = map[xy]] ij in
					if contains(ij), map[ij] == 0,
					   self[ij] == .field || self[ij] == .city || self[ij] == .airfield
						|| (p > 2 && self[ij] == .forest)
						|| (p > 4 && self[ij] == .hill)
						|| (p > 5 && self[ij] == .forestHill)
					{
						map[ij] = 1
						return ij
					} else {
						return nil
					}
				}
			}
			if nf.contains(end) { break }
			front.forEach { xy in map[xy] += 1 }
			front += nf
			if map[start] >= 127 { return false }
		}
		print("found connection")
		var head = end
		if self[end] != .city, self[end] != .airfield {
			self[end] = .roadNWSE
		}
		while head != start {
			let xy = head.n4.compactMap { xy in
				contains(xy) && self[xy] != .roadNWSE ? xy : nil
			}
			.max { a, b in map[a] < map[b] }

			if let xy {
				head = xy
				if !self[xy].isRiver, !self[xy].isBuilding {
					self[xy] = .roadNWSE
				}
			} else {
				return true
			}
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
