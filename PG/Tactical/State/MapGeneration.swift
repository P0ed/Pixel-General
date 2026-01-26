import GameplayKit

extension Map<Terrain> {

	init(size: Int, seed: Int) {
		self = Map(size: size, zero: .none)

		let size = SIMD2<Int32>(Int32(size), Int32(size))
		let seed = Int32(bitPattern: UInt32(seed & Int(UInt32.max)))
		let height = GKNoiseMap.height(size: size, seed: seed)
		let humidity = GKNoiseMap.humidity(size: size, seed: seed + 1)

		generateTerrain(height: height, humidity: humidity)
		placeRivers(height: height)
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
			self[end] = .river
			while head != start {
				let xy = head.n4.compactMap { xy in
					contains(xy) && self[xy] != .river ? xy : nil
				}
				.max { a, b in pressure[a] < pressure[b] }

				if let xy {
					head = xy
					self[xy] = .river
				} else {
					break
				}
			}
		}
	}

	private func hasNoRivers(at xy: XY) -> Bool {
		xy.n8.firstMap { xy in self[xy] == .river ? .some(xy) : .none } == .none
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
