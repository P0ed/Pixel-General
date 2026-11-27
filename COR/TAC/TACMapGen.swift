import GameplayKit

public extension Map<64, Terrain> {

	/// `terrain` is the dominant terrain of the generated map: forests raise
	/// humidity.
	init(seed: Int, players: Int = 4, terrain: Terrain = .field, density: Int = 1) {
		self.init(
			seed: seed,
			players: players,
			terrain: [16 of Terrain](repeating: terrain),
			density: density
		)
	}

	/// Generates one tactical map from a 4×4 grid of 16×16 terrain cells.
	/// The array is row-major from north-west to south-east.
	///
	/// Land entries bias the local noise; sea entries seed an
	/// impassable coast whose precise shoreline follows the height field.
	/// `spawns` are the players' spawn cells of the neighborhood. Airfields
	/// are placed near their nearest cities first, where terrain permits.
	init(seed: Int, players _: Int = 4, terrain: [16 of Terrain], density: Int = 1, spawns: [XY] = []) {
		self = Map(zero: .none)
		generate(seed: seed, terrain: terrain, targets: SettlementTargets(density), spawns: spawns)
		shapeRoads()
	}

	mutating func placeForts(around centers: [XY], level: Int) {
		placeForts(around: centers, budget: 48 * level)
	}

	internal init(scenario: Scenario) {
		self = Map(zero: .none)
		let terrain = [16 of Terrain](repeating: scenario.terrain.isSea ? .field : scenario.terrain)
		let targets = SettlementTargets(scenario.cityLevel)
		let forts = scenario.objective.defender == nil ? scenario.fortLevel : 0
		if scenario.symmetry || scenario.mapType != .land {
			var d20 = D20(seed: scenario.seed)
			let corners = Array(Scenario.spawnOptions)
			let occupied = Set(scenario.resolvedSpawnPoints)
			for i in corners.indices {
				var quarter = Map<32, Terrain>(zero: .none)
				let seed = i == 0 ? scenario.seed : Int(truncatingIfNeeded: d20.next())
				let ports = quarter.generate(
					seed: seed, terrain: terrain, targets: targets.quarter,
					starts: [(Scenario.quarterCity, Scenario.quarterAirfield)],
					mapType: scenario.mapType, reserving: scenario.mapType.joinedEdges
				)
				if scenario.symmetry {
					for edge in scenario.mapType.joinedEdges { quarter.extendRoads(to: edge) }
					quarter.placeForts(around: quarter.cityFootprints.flatMap { $0 }, budget: 12 * forts)
					for corner in corners {
						copyQuarter(quarter, to: corner, restoring: occupied.contains(corner) ? [] : ports)
					}
					break
				}
				let corner = corners[i]
				copyQuarter(quarter, to: corner, restoring: occupied.contains(corner) ? [] : ports)
			}
			if !scenario.symmetry && !scenario.mapType.joinedEdges.isEmpty {
				connectCities(cities: corners.map { Scenario.inCorner($0, tile: Scenario.quarterCity) })
			}
		} else {
			let starts = Scenario.spawnOptions.map { corner in
				(Scenario.inCorner(corner, tile: Scenario.quarterCity),
				 Scenario.inCorner(corner, tile: Scenario.quarterAirfield))
			}
			generate(seed: scenario.seed, terrain: terrain, targets: targets, starts: starts)
		}
		if !scenario.symmetry {
			placeForts(around: cityFootprints.flatMap { $0 }, level: forts)
		}
		shapeRoads()
	}

	private mutating func copyQuarter(
		_ quarter: borrowing Map<32, Terrain>, to corner: XY, restoring portGround: [PortSite]
	) {
		for xy in quarter.indices {
			self[Scenario.inCorner(corner, tile: xy)] = quarter[xy]
		}
		for site in portGround {
			self[Scenario.inCorner(corner, tile: site.port)] = site.ground
		}
	}
}

private extension MapType {
	var joinedEdges: [Edge] {
		switch self {
		case .land, .island: [.right, .top]
		case .twoIslands: [.right]
		case .fourIslands: []
		}
	}
}

private struct PortSite {
	var port: XY
	var city: XY
	var ground: Terrain
}

private struct SettlementTargets {
	var settlements: Int
	var airfields: Int
	var pairs: Int
	var triples: Int
	var portsPerPlayer: Int

	init(_ density: Int) {
		(settlements, airfields, pairs, triples, portsPerPlayer) = ([
			(24, 4, 4, 0, 1),
			(32, 6, 6, 2, 2),
			(48, 8, 8, 3, 3),
			(64, 10, 10, 4, 4)
		] as [4 of _]) [min(3, max(0, density))]
	}

	var quarter: Self {
		var result = self
		result.settlements /= 4
		result.airfields = (airfields + 2) / 4
		result.pairs = (pairs + 2) / 4
		result.triples = (triples + 2) / 4
		return result
	}
}

extension Map where Element == Terrain {

	@discardableResult
	fileprivate mutating func generate(
		seed: Int,
		terrain: [16 of Terrain],
		targets: SettlementTargets,
		spawns: [XY] = [],
		starts: [(city: XY, airfield: XY)] = [],
		mapType: MapType = .land,
		reserving edges: [Edge] = []
	) -> [PortSite] {
		let noiseSize = SIMD2<Int32>(Int32(size), Int32(size))
		let seed = Int32(truncatingIfNeeded: seed)
		let height = GKNoiseMap.height(size: noiseSize, seed: seed)
		let humidity = GKNoiseMap.humidity(size: noiseSize, seed: seed &+ 1)
		var d20 = D20(seed: Int(seed))

		var mainland = mapType == .land
			? generateTerrain(height: height, humidity: humidity, terrain: terrain)
			: generateIsland(mapType, height: height, humidity: humidity, terrain: terrain)
		for edge in edges {
			forEachEdge(edge) { xy in mainland[xy] = false }
		}
		for (city, airfield) in starts {
			self[city] = .city
			self[airfield] = .airfield
			airfield.n4.forEach { mainland[$0] = false }
		}
		placeRivers(height: height, d20: &d20)
		let ports = mapType == .land ? [] : portSites(mainland: mainland, target: targets.portsPerPlayer)
		for site in ports {
			self[site.port] = .port
			site.port.n4.forEach { mainland[$0] = false }
		}
		let cities = placeCities(
			d20: &d20, mainland: mainland, tiles: targets.settlements - targets.airfields,
			pairs: targets.pairs, triples: targets.triples, reserved: starts.map(\.city) + ports.map(\.city),
			spreadAcrossIsland: mapType != .land
		)
		placeAirfields(
			near: cities, spawns: spawns, target: targets.airfields - starts.count, d20: &d20
		)
		connectCities(cities: cities.map { $0[0] })
		return ports
	}

	internal var cityFootprints: [[XY]] {
		var visited = SetXY.empty
		var cities: [[XY]] = []
		for xy in indices where self[xy] == .city && !visited[xy] {
			cities.append(flood(from: [xy], visited: &visited) { self[$0] == .city })
		}
		return cities
	}

	private mutating func generateTerrain(
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		terrain: [16 of Terrain]
	) -> SetXY {
		indices.forEach { xy in
			self[xy] = isSea(at: xy, height: height, terrain: terrain)
				? .sea
				: landTerrain(at: xy, height: height, humidity: humidity, terrain: terrain)
		}
		removeDisconnectedSea(height: height, humidity: humidity, terrain: terrain)
		return reduceIslands()
	}

	private mutating func generateIsland(
		_ mapType: MapType, height: GKNoiseMap, humidity: GKNoiseMap, terrain: [16 of Terrain]
	) -> SetXY {
		for xy in indices {
			let noise = lowpass(height, at: xy)
			let x = mapType == .fourIslands ? min(xy.x, size - 1 - xy.x) : xy.x
			let y = mapType == .island ? xy.y : min(xy.y, size - 1 - xy.y)
			let dx = max(0, size / 2 - x)
			let dy = max(0, size / 2 - y)
			let radius = max(12, 13 + 4 * noise)
			let land = x >= 2 && y >= 2 && Float(dx * dx + dy * dy) < radius * radius
			self[xy] = land ? landTerrain(at: xy, height: height, humidity: humidity, terrain: terrain) : .sea
		}
		var land = SetXY.empty
		_ = flood(from: [Scenario.quarterCity], visited: &land) { !self[$0].isSea }
		for xy in indices where !land[xy] { self[xy] = .sea }

		var ocean = SetXY.empty
		_ = flood(from: [XY(0, 0)], visited: &ocean) { self[$0].isSea }
		for xy in indices where !land[xy] && !ocean[xy] {
			self[xy] = landTerrain(at: xy, height: height, humidity: humidity, terrain: terrain)
			land[xy] = true
		}
		return land
	}

	private func landTerrain(
		at xy: XY,
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		terrain: [16 of Terrain]
	) -> Terrain {
		let dominant = regionalTerrain(at: xy, terrain: terrain)
		let humidityBias: Float = switch dominant {
		case .forest: 0.33
		default: 0.0
		}
		return Terrain(
			height: height.value(at: xy.simd),
			humidity: humidity.value(at: xy.simd) + humidityBias
		)
	}

	/// Height can create low pockets beyond the nominal coast. Only pockets
	/// connected to a terrain sea region are ocean; disconnected ones are
	/// restored to their generated land terrain instead of becoming tiny
	/// inland sea tiles.
	private mutating func removeDisconnectedSea(
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		terrain: [16 of Terrain]
	) {
		var connected = SetXY.empty
		let seeds = indices.filter { xy in
			self[xy].isSea && regionalTerrain(at: xy, terrain: terrain).isSea
		}
		_ = flood(from: seeds, visited: &connected) { self[$0].isSea }
		for xy in indices where self[xy].isSea && !connected[xy] {
			self[xy] = landTerrain(at: xy, height: height, humidity: humidity, terrain: terrain)
		}
	}

	/// 4-connected component of `passable` tiles grown from `seeds`, extending
	/// `visited` with every tile reached.
	private func flood(from seeds: [XY], visited: inout SetXY, passable: (XY) -> Bool) -> [XY] {
		var tiles = [] as [XY]
		for seed in seeds where !visited[seed] && passable(seed) {
			visited[seed] = true
			tiles.append(seed)
		}
		var head = 0
		while head < tiles.count {
			let neighbors = tiles[head].n4
			head += 1
			for i in neighbors.indices {
				let p = neighbors[i]
				guard contains(p), !visited[p], passable(p) else { continue }
				visited[p] = true
				tiles.append(p)
			}
		}
		return tiles
	}

	/// The largest contiguous landmass is the mainland. Other components are
	/// islands: tiny ones are submerged to keep the coast readable, while any
	/// larger retained islands are left out of the mask returned to settlement
	/// placement.
	private mutating func reduceIslands() -> SetXY {
		var visited = SetXY.empty
		var landmasses = [] as [[XY]]
		for start in indices where !self[start].isSea && !visited[start] {
			landmasses.append(flood(from: [start], visited: &visited) { !self[$0].isSea })
		}
		guard let mainlandIndex = landmasses.indices.max(by: { a, b in
			landmasses[a].count < landmasses[b].count
		}) else { return .empty }

		let minimumIslandArea = max(6, count / 96)
		for index in landmasses.indices
			where index != mainlandIndex && landmasses[index].count < minimumIslandArea {
			landmasses[index].forEach { xy in self[xy] = .sea }
		}
		return SetXY(landmasses[mainlandIndex])
	}

	/// Treats the terrain sea mask as the broad coastline, then moves
	/// that coastline inland at low elevations and out to sea at high ones.
	/// Distance from the nearest sea-cell center adds a growing landward bias,
	/// so peripheral water needs distinctly lower elevation than the sea core.
	/// Capping nominal sea depth keeps that bias relevant even in an outer map
	/// corner far from every terrain land cell.
	private func isSea(at xy: XY, height: GKNoiseMap, terrain: [16 of Terrain]) -> Bool {
		let hasSea = terrain.contains { $0.isSea }
		guard hasSea else { return false }
		guard terrain.contains({ !$0.isSea }) else { return true }

		let point = SIMD2<Float>(Float(xy.x) + 0.5, Float(xy.y) + 0.5) / Float(size / 4)
		var seaDistance = Float.greatestFiniteMagnitude
		var landDistance = Float.greatestFiniteMagnitude
		var seaCenterDistance = Float.greatestFiniteMagnitude
		for index in terrain.indices {
			let cell = XY(terrainIndex: index)
			let origin = SIMD2<Float>(Float(cell.x), Float(cell.y))
			let distance = distance(from: point, toCellAt: origin)
			if terrain[index].isSea {
				seaDistance = min(seaDistance, distance)
				let centerOffset = point - origin - 0.5
				seaCenterDistance = min(
					seaCenterDistance,
					(centerOffset.x * centerOffset.x + centerOffset.y * centerOffset.y).squareRoot()
				)
			} else {
				landDistance = min(landDistance, distance)
			}
		}

		let elevation = 0.6 * lowpass(height, at: xy) + 0.4 * height.value(at: xy.simd)
		let seaDepth = min(landDistance, 0.8)
		let centerPenalty = max(0, seaCenterDistance - 0.2) * 0.65
		return (seaDistance - seaDepth + centerPenalty + elevation) * 0.75 + 0.05 < 0
	}

	private func distance(from point: SIMD2<Float>, toCellAt origin: SIMD2<Float>) -> Float {
		let dx = max(0, max(origin.x - point.x, point.x - origin.x - 1))
		let dy = max(0, max(origin.y - point.y, point.y - origin.y - 1))
		return (dx * dx + dy * dy).squareRoot()
	}

	private func regionalTerrain(at xy: XY, terrain: [16 of Terrain]) -> Terrain {
		let width = size / 4
		return terrain[XY(xy.x / width, xy.y / width).terrainIndex]
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
				let preferredEdge = Edge.allCases.randomElement(using: &d20),
				let (edge, source) = riverSource(
					preferredEdge: preferredEdge,
					height: height,
					d20: &d20,
					apart: mouths
				)
			else { return }

			let salt = d20.next()
			let meander = GKNoiseMap.meander(
				size: SIMD2<Int32>(Int32(size), Int32(size)),
				seed: Int32(truncatingIfNeeded: salt)
			)
			var mouth = nil as XY?
			if idx == 0 || d20() >= 8 {
				mouth = coastalRiverMouth(height: height, apart: mouths, across: source)
				if mouth == nil {
					let across = d20() < 14
						? edge.opposite
						: Edge.allCases.filter { e in e != edge && e != edge.opposite }
							.randomElement(using: &d20) ?? edge.opposite
					mouth = riverMouth(on: across, height: height, d20: &d20, apart: mouths, across: source)
						?? riverMouth(on: edge.opposite, height: height, d20: &d20, apart: mouths, across: source)
				}
				guard mouth != nil else { return }
			}

			let path = shortestPath(
				from: [source],
				reached: { xy in mouth.map { m in xy == m } ?? self[xy].isRiver },
				cost: { _, xy in riverStep(to: xy, mouth: mouth, height: height, meander: meander, salt: salt) }
			)
			guard let path else { return }
			path.forEach { xy in self[xy] = .river }
			mouths.append(source)
			mouth.map { m in mouths.append(m) }
		}
	}

	/// Tries the seeded edge first, then the remaining edges. Coastal maps can
	/// submerge an entire edge, which should not cancel a river when a valid
	/// inland source exists elsewhere on the map boundary.
	private func riverSource(
		preferredEdge: Edge,
		height: GKNoiseMap,
		d20: inout D20,
		apart mouths: [XY]
	) -> (Edge, XY)? {
		let edges = [preferredEdge] + Edge.allCases.filter { $0 != preferredEdge }
		for edge in edges {
			if let source = riverMouth(on: edge, height: height, d20: &d20, apart: mouths) {
				return (edge, source)
			}
		}
		return nil
	}

	/// Lowest-lying of a few random candidates on `edge`, so mouths favor
	/// valleys without starting beside a sea shore. Mouths keep apart from
	/// other rivers' mouths, and an exit must be far enough from its `source`
	/// that the river genuinely crosses the map rather than clipping a corner.
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
				!self[p].isSea, !self[p].isSettlement,
				hasNoSeaNeighbors(at: p),
				hasNoRivers(at: p),
				mouths.allSatisfy({ xy in xy.stepDistance(to: p) >= size / 2 }),
				source.map({ xy in xy.manhattanDistance(to: p) >= size - 1 }) ?? true,
				best.map({ xy in height.value(at: p.simd) < height.value(at: xy.simd) }) ?? true
			else { return }
			best = p
		}
		return best
	}

	/// Lowest coastal land reachable far enough from `source` to form a real
	/// river. The pathfinder may enter this tile as its goal, but shoreline
	/// land is otherwise impassable, making it a terminal river mouth rather
	/// than a route that follows the coast.
	private func coastalRiverMouth(
		height: GKNoiseMap,
		apart mouths: [XY],
		across source: XY
	) -> XY? {
		var best = nil as XY?
		for p in indices {
			guard
				!self[p].isSea, !self[p].isSettlement,
				touchesSea(at: p),
				p.n4.contains({ q in contains(q) && !self[q].isSea && hasNoSeaNeighbors(at: q) }),
				hasNoRivers(at: p),
				mouths.allSatisfy({ xy in xy.stepDistance(to: p) >= size / 2 }),
				source.manhattanDistance(to: p) >= size / 2,
				best.map({ xy in height.value(at: p.simd) < height.value(at: xy.simd) }) ?? true
			else { continue }
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
	/// the terrain is flat, and a penalty for hugging the map border. Shoreline
	/// land is impassable except for the selected terminal mouth, so a river
	/// can meet the sea but cannot run along it. Land next to an existing river
	/// is also impassable so parallel rivers keep a gap — a tributary
	/// (`mouth == nil`) instead pays a penalty there and terminates on the
	/// first river tile it touches.
	private func riverStep(to xy: XY, mouth: XY?, height: GKNoiseMap, meander: GKNoiseMap, salt: UInt64) -> UInt32? {
		guard contains(xy), !self[xy].isSea, !self[xy].isSettlement else { return nil }
		if !hasNoSeaNeighbors(at: xy), mouth.map({ $0 == xy }) != true { return nil }
		if self[xy].isRiver { return mouth == nil ? 1 : nil }
		let near = !hasNoRivers(at: xy)
		if near, mouth != nil { return nil }
		let macro = lowpass(height, at: xy)
		let local = height.value(at: xy.simd)
		let lift = max(0, min(2, 0.75 * macro + 0.25 * local + 1))
		let bend = max(0, min(2, meander.value(at: xy.simd) + 1))
		var cost = UInt32(3 + lift * lift * 16 + bend * bend * 24) + wiggle(xy, salt)
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
	private func wiggle(_ xy: XY, _ salt: UInt64) -> UInt32 {
		var mix = D20(seed: salt &+ UInt64(bitPattern: Int64(xy.y &* 64 &+ xy.x)))
		return UInt32(mix.next() & 3)
	}

	private func hasNoRivers(at xy: XY) -> Bool {
		xy.n8.firstMap { xy in self[xy].isRiver ? .some(xy) : .none } == .none
	}

	private func hasNoSeaNeighbors(at xy: XY) -> Bool {
		!xy.n8.contains { p in self[p].isSea }
	}

	private func touchesSea(at xy: XY) -> Bool {
		xy.n4.contains { p in self[p].isSea }
	}

	private func portSites(mainland: SetXY, target: Int) -> [PortSite] {
		let home = Scenario.quarterCity
		let spacing = max(2, size / 8)
		func isOpen(_ xy: XY) -> Bool {
			mainland[xy] && !self[xy].isWater && !self[xy].isSettlement
		}

		var candidates: [PortSite] = []
		for port in indices where isOpen(port) && touchesSea(at: port) {
			for city in port.n4 where isOpen(city) && city.stepDistance(to: home) >= spacing {
				guard city.n4.contains({ xy in xy != port && isOpen(xy) && self[xy] != .mountain }) else { continue }
				candidates.append(PortSite(port: port, city: city, ground: self[port]))
			}
		}
		func select(from candidates: [PortSite], sites: inout [PortSite]) -> Bool {
			if sites.count == target { return true }
			let centers = [home] + sites.map(\.city)
			let ranked = candidates.map { site in
				(site: site, distance: centers.map { site.city.stepDistance(to: $0) }.min()!)
			}.sorted { $0.distance > $1.distance }.map(\.site)
			for (index, site) in ranked.enumerated() {
				let available = ranked.dropFirst(index + 1).filter { other in
					site.port.manhattanDistance(to: other.port) > 1
					&& site.port.manhattanDistance(to: other.city) > 1
					&& site.city.manhattanDistance(to: other.port) > 1
					&& site.city.stepDistance(to: other.city) >= spacing
				}
				sites.append(site)
				if select(from: available, sites: &sites) { return true }
				sites.removeLast()
			}
			return false
		}

		var sites: [PortSite] = []
		let complete = select(from: candidates, sites: &sites)
		precondition(complete)
		return sites
	}

	private mutating func placeCities(
		d20: inout D20,
		mainland: SetXY,
		tiles: Int,
		pairs: Int,
		triples: Int,
		reserved: [XY] = [],
		spreadAcrossIsland: Bool = false
	) -> [[XY]] {
		let centerTarget = tiles - pairs - 2 * triples

		var cols = 1
		while cols * (cols + 1) < centerTarget { cols += 1 }
		let rows = (centerTarget + cols - 1) / cols
		let minSpacing = max(2, size / 8)

		let margin = 1
		let span = size - 2 * margin
		// Keep the same 53-bit draw, then place the city 15–85% across its cell.
		let jitterSteps = 1 << 53
		let scale = 100 * Int128(jitterSteps)
		func coordinate(in cell: Int, outOf count: Int, using d20: inout D20) -> Int {
			let draw = Int.random(in: 0 ... jitterSteps, using: &d20)
			let jitter = 15 * Int128(jitterSteps) + 70 * Int128(draw)
			let offset = (Int128(cell) * scale + jitter) * Int128(span)
			return margin + Int(offset / (Int128(count) * scale))
		}

		func isCityLand(_ p: XY) -> Bool {
			mainland[p]
			&& !self[p].isWater
			&& !self[p].isSettlement
			&& self[p] != .mountain
		}

		func isCitySite(_ p: XY, awayFrom cities: [[XY]], except current: Int? = nil) -> Bool {
			isCityLand(p) && !cities.indices.contains { i in
				i != current && cities[i].contains { $0.stepDistance(to: p) < minSpacing }
			}
		}

		var cities = reserved.map { [$0] }

		func fillCitySites(upTo target: Int) {
			guard cities.count < target else { return }
			if spreadAcrossIsland {
				let districts = cities.flatMap { $0 }
				var sites = indices.filter { isCityLand($0) && hasNoSeaNeighbors(at: $0) }.map { xy in
					(xy: xy, distance: districts.map { xy.stepDistance(to: $0) }.min() ?? .max)
				}
				while cities.count < target, let best = sites.max(by: { $0.distance < $1.distance }),
					best.distance >= minSpacing {
					let center = best.xy
					cities.append([center])
					for j in sites.indices {
						sites[j].distance = min(sites[j].distance, sites[j].xy.stepDistance(to: center))
					}
				}
			} else {
				for xy in indices where cities.count < target && isCitySite(xy, awayFrom: cities) {
					cities.append([xy])
				}
			}
		}

		for i in 0 ..< centerTarget where !spreadAcrossIsland && cities.count < centerTarget {
			let gx = i % cols
			let gy = i / cols
			let center = XY(
				coordinate(in: gx, outOf: cols, using: &d20),
				coordinate(in: gy, outOf: rows, using: &d20)
			)
			if isCitySite(center, awayFrom: cities) {
				cities.append([center])
			} else if let nearby = center.n36.firstMap({ isCitySite($0, awayFrom: cities) ? $0 : nil }) {
				cities.append([nearby])
			}
		}

		fillCitySites(upTo: centerTarget)

		var remaining = tiles - cities.count
		for (districts, target) in [(3, triples), (2, pairs)] {
			var grown = 0
			for i in cities.indices.dropFirst(reserved.count) where grown < target && cities[i].count == 1 {
				var footprint = cities[i]
				var head = 0
				while head < footprint.count && footprint.count < districts {
					for p in footprint[head].n4 where footprint.count < districts {
						if !footprint.contains(p), isCitySite(p, awayFrom: cities, except: i) {
							footprint.append(p)
						}
					}
					head += 1
				}
				guard footprint.count == districts else { continue }
				cities[i] = footprint
				remaining -= districts - 1
				grown += 1
			}
		}

		if remaining > 0 { fillCitySites(upTo: cities.count + remaining) }
		for city in cities {
			for xy in city { self[xy] = .city }
		}
		return cities
	}

	private mutating func placeAirfields(
		near cities: [[XY]], spawns: [XY], target: Int, d20: inout D20
	) {
		var remaining = target
		let districts = cities.flatMap { $0 }
		for spawn in spawns {
			guard remaining > 0 else { return }
			let center = spawn.cellCenter(size: size)
			let ranked = districts.sorted { a, b in
				(a.manhattanDistance(to: center), a.y, a.x)
					< (b.manhattanDistance(to: center), b.y, b.x)
			}
			for city in ranked {
				if hasAirfield(near: city) { break }
				if placeAirfield(near: city, d20: &d20, clearing: true) {
					remaining -= 1
					break
				}
			}
		}

		guard remaining > 0 else { return }
		let sites = cities.shuffled(using: &d20)
		for city in sites where remaining > 0 {
			guard !city.contains(where: { hasAirfield(near: $0) }) else { continue }
			if city.contains(where: { placeAirfield(near: $0, d20: &d20) }) {
				remaining -= 1
			}
		}
		// If few footprints have clear ground, use other open sites nearby.
		while remaining > 0, districts.contains(where: { placeAirfield(near: $0, d20: &d20, clearing: true) }) {
			remaining -= 1
		}
	}

	private func hasAirfield(near city: XY) -> Bool {
		city.n4.contains { ap in contains(ap) && self[ap] == .airfield }
	}

	private mutating func placeAirfield(
		near city: XY,
		d20: inout D20,
		clearing: Bool = false
	) -> Bool {
		var candidates = city.n4.compactMap { p in
			contains(p) && self[p] == .field ? p : nil
		}
		if clearing, candidates.isEmpty {
			candidates = city.n4.compactMap { p in
				contains(p) && [.forest, .rough].contains(self[p]) ? p : nil
			}
		}
		guard let ap = candidates.randomElement(using: &d20) else { return false }
		self[ap] = .airfield
		return true
	}

	/// Cities join a road network shaped the way real ones grow: a minimum
	/// spanning forest over terrain-aware travel costs links every reachable
	/// city without redundant spaghetti, short links carve first so longer
	/// routes reuse them as trunks, and a few extra edges then close the
	/// worst detours into loops.
	internal mutating func connectCities(cities: [XY]) {
		guard cities.count > 1 else { return }

		let costs = travelCosts(between: cities)
		var carved = [] as [(a: Int, b: Int)]
		spanningEdges(costs: costs)
			.sorted { lhs, rhs in (lhs.w, lhs.a, lhs.b) < (rhs.w, rhs.a, rhs.b) }
			.forEach { e in
				if connect(cities[e.a], cities[e.b]) { carved.append((e.a, e.b)) }
			}
		detourEdges(costs: costs, carved: carved).forEach { e in
			_ = connect(cities[e.a], cities[e.b])
		}
	}

	/// Cheapest travel cost between every pair of cities on the pristine
	/// (pre-road) map, from one Dijkstra flood per city. `.max` marks pairs
	/// with no route at all — opposite banks of an unbridgable river — that
	/// no road should attempt.
	private func travelCosts(between cities: [XY]) -> [[UInt32]] {
		var costs = Array(
			repeating: Array(repeating: UInt32.max, count: cities.count),
			count: cities.count
		)
		cities.indices.forEach { i in costs[i][i] = 0 }
		cities.indices.dropLast().forEach { i in
			let dist = distances(from: cities[i])
			(i + 1 ..< cities.count).forEach { j in
				costs[i][j] = dist[cities[j]]
				costs[j][i] = dist[cities[j]]
			}
		}
		return costs
	}

	/// Prim's minimum spanning forest over the travel-cost matrix. When
	/// rivers split the map each side grows its own tree, so every city
	/// still joins the cheapest network available to it.
	private func spanningEdges(costs: [[UInt32]]) -> [(a: Int, b: Int, w: UInt32)] {
		let n = costs.count
		var linkW = Array(repeating: UInt32.max, count: n)
		var linkTo = Array(repeating: -1, count: n)
		var inTree = Array(repeating: false, count: n)
		var edges = [] as [(a: Int, b: Int, w: UInt32)]
		linkW[0] = 0

		(0 ..< n).forEach { _ in
			guard let u = (0 ..< n)
				.filter({ i in !inTree[i] })
				.min(by: { a, b in linkW[a] < linkW[b] })
			else { return }
			if linkTo[u] >= 0 {
				edges.append((linkTo[u], u, linkW[u]))
			}
			inTree[u] = true
			(0 ..< n).forEach { v in
				if !inTree[v], costs[u][v] < linkW[v] {
					linkW[v] = costs[u][v]
					linkTo[v] = u
				}
			}
		}
		return edges
	}

	/// Non-tree city pairs whose route through the carved network runs far
	/// longer than a direct road, worst first — the loops real networks grow
	/// once trunks exist. Network distances run over the abstract carved
	/// graph (Floyd–Warshall over the city centers), refreshed after each
	/// pick so one new link can cure several detours.
	private func detourEdges(
		costs: [[UInt32]],
		carved: [(a: Int, b: Int)]
	) -> [(a: Int, b: Int)] {
		let n = costs.count
		let far = UInt32.max / 2
		var net = Array(repeating: Array(repeating: far, count: n), count: n)
		(0 ..< n).forEach { i in net[i][i] = 0 }

		func relax() {
			(0 ..< n).forEach { k in
				(0 ..< n).forEach { i in
					(0 ..< n).forEach { j in
						net[i][j] = min(net[i][j], net[i][k] + net[k][j])
					}
				}
			}
		}
		carved.forEach { e in
			net[e.a][e.b] = costs[e.a][e.b]
			net[e.b][e.a] = net[e.a][e.b]
		}
		relax()

		var extras = [] as [(a: Int, b: Int)]
		(0 ..< max(1, n / 5)).forEach { _ in
			var pick = nil as (a: Int, b: Int)?
			var worstDistance: UInt64 = 9
			var worstDirect: UInt64 = 5
			(0 ..< n).forEach { i in
				(i + 1 ..< n).forEach { j in
					guard costs[i][j] < .max, net[i][j] < far else { return }
					let distance = UInt64(net[i][j])
					let direct = UInt64(costs[i][j])
					if distance * worstDirect > worstDistance * direct {
						worstDistance = distance
						worstDirect = direct
						pick = (i, j)
					}
				}
			}
			guard let pick else { return }
			extras.append(pick)
			net[pick.a][pick.b] = costs[pick.a][pick.b]
			net[pick.b][pick.a] = net[pick.a][pick.b]
			relax()
		}
		return extras
	}

	public mutating func shapeRoads() {
		var neighbors = [false, false, false, false] as [4 of Bool]
		for xy in indices {
			if self[xy].isRoad {
				let n4 = xy.n4
				for i in n4.indices {
					neighbors[i] = self[n4[i]].hasRoad
				}
				let r = Self.road(neighbors)
				if r != .none { self[xy] = r }
			} else if self[xy].isBridge {
				let n4 = xy.n4
				let westEast = [n4[0], n4[2]].allSatisfy { self[$0].isRiver || self[$0] == .bridgeSN }
				let southNorth = [n4[1], n4[3]].allSatisfy { self[$0].isRiver || self[$0] == .bridgeWE }
				if westEast, !southNorth {
					self[xy] = .bridgeSN
				} else if southNorth, !westEast {
					self[xy] = .bridgeWE
				}
			}
		}
	}

	/// Forts land last, after generation, as defensive rings `.r12` around
	/// `centers` — the defending side's cities.
	/// Only open ground (field/forest/hill) turns into fort, so roads keep
	/// their gaps through the ring and rivers/settlements stay untouched.
	/// At most `48 * level` tiles land across the full map, one per center
	/// per round-robin pass so the budget spreads evenly across cities.
	/// No RNG — placement is a pure function of the map and inputs.
	fileprivate mutating func placeForts(around centers: [XY], budget: Int) {
		var budget = budget
		var cursors = [Int](repeating: 0, count: centers.count)
		var placed = true
		while budget > 0, placed {
			placed = false
			for k in centers.indices {
				guard budget > 0 else { return }
				let ring = centers[k].r12
				scan: while cursors[k] < ring.count {
					let xy = ring[cursors[k]]
					cursors[k] += 1
					switch self[xy] {
					case .field, .forest, .rough:
						self[xy] = .fort
						budget -= 1
						placed = true
						break scan
					default: break
					}
				}
			}
		}
	}

	private static func road(_ neighbors: [4 of Bool]) -> Terrain {
		// East, North, West, South
		switch (neighbors[0], neighbors[1], neighbors[2], neighbors[3]) {
		case (false, true, false, _), (false, false, false, true): .roadSN
		case (true, false, _, false), (false, false, true, false): .roadWE
		case (true, true, false, false): .roadNE
		case (true, false, false, true): .roadSE
		case (false, true, true, false): .roadNW
		case (false, false, true, true): .roadSW
		case (false, true, true, true): .roadTE
		case (true, false, true, true): .roadTN
		case (true, true, false, true): .roadTW
		case (true, true, true, false): .roadTS
		case (true, true, true, true): .roadX
		default: .none
		}
	}

	private func bridgableRiver(at r: XY, from l: XY) -> Bool {
		guard self[r].isRiver, self[l].isBridgable else { return false }
		let step = r - l
		let n4 = r.n4
		guard self[r + step].isBridgable else { return false }
		return step.x == 0
			? self[n4[0]].isRiver && self[n4[2]].isRiver
			: self[n4[1]].isRiver && self[n4[3]].isRiver
	}

	/// Cost of stepping onto `to` from `l`, or `nil` if impassable. Roads and
	/// cities are nearly free, open ground is cheap, and forest/hills cost
	/// progressively more so a route only carves through them when there's no
	/// gentler way around. Rivers are passable solely where a bridge fits.
	private func stepCost(to: XY, from l: XY) -> UInt32? {
		let crossing = to.x == l.x ? Terrain.bridgeSN : .bridgeWE
		if self[l].isBridge, self[l] != crossing { return nil }
		let t = self[to]
		if t.isBridge { return t == crossing ? 1 : nil }
		if t.hasRoad { return 1 }
		switch t {
		case .field: return 4
		case .forest: return 6
		case .rough: return 10
		default: return bridgableRiver(at: to, from: l) ? 8 : nil
		}
	}

	private mutating func connect(_ start: XY, _ end: XY) -> Bool {
		guard let path = shortestPath(
			from: [start],
			reached: { xy in xy == end },
			cost: { from, to in stepCost(to: to, from: from) }
		) else { return false }
		carveRoad(path)
		return true
	}

	fileprivate mutating func extendRoads(to edge: Edge) {
		let roads = indices.filter { self[$0].isRoad || self[$0] == .city }
		if let path = shortestPath(
			from: roads,
			reached: { xy in
				(edge == .right ? xy.x : xy.y) == size - 1 && !self[xy].isRiver && !self[xy].isBridge
			},
			cost: { from, to in stepCost(to: to, from: from) }
		) {
			carveRoad(path)
		}
	}

	private mutating func carveRoad(_ path: [XY]) {
		for (i, xy) in path.enumerated() where !self[xy].isSettlement && !self[xy].isBridge {
			if self[xy].isRiver {
				self[xy] = path[i + 1].x == xy.x ? .bridgeSN : .bridgeWE
			} else {
				self[xy] = .roadX
			}
		}
	}

	/// Dijkstra over 4-neighbors from `starts` until a tile satisfying
	/// `reached` is finalized, following `cost(from, to)` (`nil` =
	/// impassable). Returns the path including both endpoints.
	private func shortestPath(
		from starts: [XY],
		reached: (XY) -> Bool,
		cost: (XY, XY) -> UInt32?
	) -> [XY]? {
		var dist = Map<size, UInt32>(zero: .max)
		var prev = Map<size, UInt16>(zero: 0)
		guard let goal = dijkstra(from: starts, reached: reached, cost: cost, dist: &dist, prev: &prev)
		else { return nil }

		var path = [goal]
		var head = goal
		while prev[head] != 0 {
			let packed = prev[head]
			let idx = Int(packed) - 1
			head = XY(idx % size, idx / size)
			path.append(head)
		}
		return path
	}

	/// Travel cost from `start` to every tile over `stepCost` terrain,
	/// flooded to exhaustion; `.max` = unreachable.
	private func distances(from start: XY) -> Map<size, UInt32> {
		var dist = Map<size, UInt32>(zero: .max)
		var prev = Map<size, UInt16>(zero: 0)
		_ = dijkstra(
			from: [start],
			reached: { _ in false },
			cost: { from, to in stepCost(to: to, from: from) },
			dist: &dist,
			prev: &prev
		)
		return dist
	}

	/// Core of `shortestPath`/`distances`: relaxes `dist`/`prev` outward
	/// from `start` and returns the first finalized tile satisfying
	/// `reached`, or `nil` once the flood exhausts.
	private func dijkstra(
		from starts: [XY],
		reached: (XY) -> Bool,
		cost: (XY, XY) -> UInt32?,
		dist: inout Map<size, UInt32>,
		prev: inout Map<size, UInt16>
	) -> XY? {
		var heap = starts.map { (distance: UInt32(0), point: $0) }
		for start in starts { dist[start] = 0 }

		func siftUp(_ from: Int) {
			var i = from
			while i > 0 {
				let parent = (i - 1) / 2
				if heap[parent].distance <= heap[i].distance { break }
				heap.swapAt(parent, i)
				i = parent
			}
		}
		func siftDown(_ from: Int) {
			var i = from
			while true {
				let l = 2 * i + 1, r = 2 * i + 2
				var m = i
				if l < heap.count, heap[l].distance < heap[m].distance { m = l }
				if r < heap.count, heap[r].distance < heap[m].distance { m = r }
				if m == i { break }
				heap.swapAt(m, i)
				i = m
			}
		}

		while let (distance, point) = heap.first {
			let last = heap.removeLast()
			if !heap.isEmpty {
				heap[0] = last
				siftDown(0)
			}
			if distance != dist[point] { continue }
			if reached(point) { return point }

			let n4 = point.n4
			for i in n4.indices {
				let nb = n4[i]
				guard contains(nb), let w = cost(point, nb) else { continue }
				let nd = distance + w
				if nd < dist[nb] {
					dist[nb] = nd
					prev[nb] = UInt16(point.y * size + point.x + 1)
					heap.append((nd, nb))
					siftUp(heap.count - 1)
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
		case 0.3 ..< 0.7: humidity > height ? .forest : .rough
		case 0.7 ..< 0.85: .rough
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
