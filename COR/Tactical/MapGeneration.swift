import GameplayKit

public extension Map<32, Terrain> {

	/// `terrain` is the dominant terrain of the generated map: hills and
	/// mountains lift the height field, while forests raise humidity. Campaign
	/// battles pass the contested province's strategic terrain here.
	init(size: Int, seed: Int, players: Int = 4, terrain: Terrain = .field) {
		self.init(
			size: size,
			seed: seed,
			players: players,
			terrain: [9 of Terrain](repeating: terrain)
		)
	}

	/// Generates one tactical map from a 3×3 strategic neighborhood. The
	/// array is row-major from north-west to south-east:
	///
	///     0 1 2
	///     3 4 5
	///     6 7 8
	///
	/// Campaign battles rotate their sample so the attacker is at 3 and the
	/// defender at 4. Land entries bias the local noise; sea entries seed an
	/// impassable coast whose precise shoreline follows the height field.
	init(size: Int, seed: Int, players: Int = 4, terrain: [9 of Terrain]) {
		self = Map(size: size, zero: .none)

		let noiseSize = SIMD2<Int32>(Int32(size), Int32(size))
		let seed = Int32(bitPattern: UInt32(seed & Int(UInt32.max)))
		let height = GKNoiseMap.height(size: noiseSize, seed: seed)
		let humidity = GKNoiseMap.humidity(size: noiseSize, seed: seed + 1)
		var d20 = D20(seed: UInt64(bitPattern: Int64(seed)))

		let mainland = generateTerrain(
			height: height,
			humidity: humidity,
			terrain: terrain
		)
		placeRivers(height: height, d20: &d20)
		let cities = placeCities(d20: &d20, players: players, mainland: mainland)
		connectCities(cities: cities)
		shapeRoads()
	}

	private mutating func generateTerrain(
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		terrain: [9 of Terrain]
	) -> SetXY {
		indices.forEach { xy in
			let dominant = strategicTerrain(at: xy, terrain: terrain)
			guard !isSea(at: xy, height: height, terrain: terrain) else {
				self[xy] = .sea
				return
			}
			self[xy] = landTerrain(at: xy, height: height, humidity: humidity, dominant: dominant)
		}
		removeDisconnectedSea(height: height, humidity: humidity, terrain: terrain)
		return reduceIslands()
	}

	private func landTerrain(
		at xy: XY,
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		dominant: Terrain
	) -> Terrain {
		let humidityBias: Float = switch dominant {
		case .forest, .forestHill: 0.5
		default: 0.0
		}
		return Terrain(
			height: height.value(at: xy.simd) + 0.25 * Float(dominant.elevationLevel),
			humidity: humidity.value(at: xy.simd) + humidityBias
		)
	}

	/// Height can create low pockets beyond the nominal coast. Only pockets
	/// connected to the strategic sea region are ocean; disconnected ones are
	/// restored to their generated land terrain instead of becoming tiny
	/// inland sea tiles.
	private mutating func removeDisconnectedSea(
		height: GKNoiseMap,
		humidity: GKNoiseMap,
		terrain: [9 of Terrain]
	) {
		var connected = SetXY.empty
		var pending = [] as [XY]
		for xy in indices
			where self[xy].isSea && strategicTerrain(at: xy, terrain: terrain).isSea {
			connected[xy] = true
			pending.append(xy)
		}
		while let xy = pending.popLast() {
			let neighbors = xy.n4
			for i in neighbors.indices {
				let p = neighbors[i]
				guard self[p].isSea && !connected[p] else { continue }
				connected[p] = true
				pending.append(p)
			}
		}
		for xy in indices where self[xy].isSea && !connected[xy] {
			let dominant = strategicTerrain(at: xy, terrain: terrain)
			self[xy] = landTerrain(at: xy, height: height, humidity: humidity, dominant: dominant)
		}
	}

	/// The largest contiguous landmass is the mainland. Other components are
	/// islands: tiny ones are submerged to keep the coast readable, while any
	/// larger retained islands are left out of the mask returned to settlement
	/// placement.
	private mutating func reduceIslands() -> SetXY {
		var visited = SetXY.empty
		var landmasses = [] as [[XY]]
		for start in indices where !self[start].isSea && !visited[start] {
			var landmass = [start]
			var head = 0
			visited[start] = true
			while head < landmass.count {
				let neighbors = landmass[head].n4
				head += 1
				for i in neighbors.indices {
					let p = neighbors[i]
					guard contains(p), !self[p].isSea, !visited[p] else { continue }
					visited[p] = true
					landmass.append(p)
				}
			}
			landmasses.append(landmass)
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

	/// Treats the 3×3 strategic sea mask as the broad coastline, then moves
	/// that coastline inland at low elevations and out to sea at high ones.
	/// Distance from the nearest sea-cell center adds a growing landward bias,
	/// so peripheral water needs distinctly lower elevation than the sea core.
	/// Capping nominal sea depth keeps that bias relevant even in an outer map
	/// corner far from every strategic land cell.
	private func isSea(at xy: XY, height: GKNoiseMap, terrain: [9 of Terrain]) -> Bool {
		let hasSea = terrain.contains { $0.isSea }
		guard hasSea else { return false }
		guard terrain.contains({ !$0.isSea }) else { return true }

		let scale = 3.0 / Float(size)
		let point = SIMD2<Float>(
			(Float(xy.x) + 0.5) * scale,
			(Float(xy.y) + 0.5) * scale
		)
		var seaDistance = Float.greatestFiniteMagnitude
		var landDistance = Float.greatestFiniteMagnitude
		var seaCenterDistance = Float.greatestFiniteMagnitude
		for index in terrain.indices {
			let column = index % 3
			let rowFromSouth = 2 - index / 3
			let cell = SIMD2<Float>(Float(column), Float(rowFromSouth))
			let distance = distance(
				from: point,
				toCellAt: cell
			)
			if terrain[index].isSea {
				seaDistance = min(seaDistance, distance)
				let centerOffset = point - cell - SIMD2<Float>(repeating: 0.5)
				seaCenterDistance = min(
					seaCenterDistance,
					(centerOffset.x * centerOffset.x + centerOffset.y * centerOffset.y).squareRoot()
				)
			} else {
				landDistance = min(landDistance, distance)
			}
		}

		let elevation = 0.6 * lowpass(height, at: xy) + 0.4 * height.value(at: xy.simd)
		let seaDepth = min(landDistance, 0.6)
		let centerPenalty = max(0, seaCenterDistance - 0.15) * 0.65
		return seaDistance - seaDepth + centerPenalty + 0.05 + elevation * 0.75 < 0
	}

	private func distance(from point: SIMD2<Float>, toCellAt origin: SIMD2<Float>) -> Float {
		let dx = max(0, max(origin.x - point.x, point.x - origin.x - 1))
		let dy = max(0, max(origin.y - point.y, point.y - origin.y - 1))
		return (dx * dx + dy * dy).squareRoot()
	}

	private func strategicTerrain(at xy: XY, terrain: [9 of Terrain]) -> Terrain {
		let column = min(2, xy.x * 3 / size)
		let rowFromSouth = min(2, xy.y * 3 / size)
		let rowFromNorth = 2 - rowFromSouth
		return terrain[rowFromNorth * 3 + column]
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
				from: source,
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
				!self[p].isSea,
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
				!self[p].isSea,
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
	private func riverStep(to xy: XY, mouth: XY?, height: GKNoiseMap, meander: GKNoiseMap, salt: UInt64) -> UInt16? {
		guard contains(xy), !self[xy].isSea else { return nil }
		if !hasNoSeaNeighbors(at: xy), mouth.map({ $0 == xy }) != true { return nil }
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

	private func hasNoSeaNeighbors(at xy: XY) -> Bool {
		xy.n8.firstMap { p in self[p].isSea ? .some(p) : .none } == .none
	}

	private func touchesSea(at xy: XY) -> Bool {
		xy.n4.firstMap { p in self[p].isSea ? .some(p) : .none } != .none
	}

	private mutating func placeCities(d20: inout D20, players: Int, mainland: SetXY) -> [XY] {
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
			&& mainland[p]
			&& !self[p].isWater
			&& !self[p].isSettlement
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

	/// Cities join a road network shaped the way real ones grow: a minimum
	/// spanning forest over terrain-aware travel costs links every reachable
	/// city without redundant spaghetti, short links carve first so longer
	/// routes reuse them as trunks, and a few extra edges then close the
	/// worst detours into loops.
	private mutating func connectCities(cities: [XY]) {
		let cities = cities.filter { xy in self[xy] == .city }
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
	private func travelCosts(between cities: [XY]) -> [[UInt16]] {
		var costs = Array(
			repeating: Array(repeating: UInt16.max, count: cities.count),
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
	private func spanningEdges(costs: [[UInt16]]) -> [(a: Int, b: Int, w: UInt16)] {
		let n = costs.count
		var linkW = Array(repeating: UInt16.max, count: n)
		var linkTo = Array(repeating: -1, count: n)
		var inTree = Array(repeating: false, count: n)
		var edges = [] as [(a: Int, b: Int, w: UInt16)]
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
	/// graph (Floyd–Warshall over at most 16 cities), refreshed after each
	/// pick so one new link can cure several detours.
	private func detourEdges(
		costs: [[UInt16]],
		carved: [(a: Int, b: Int)]
	) -> [(a: Int, b: Int)] {
		let n = costs.count
		let far = 1 << 20
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
			net[e.a][e.b] = Int(costs[e.a][e.b])
			net[e.b][e.a] = net[e.a][e.b]
		}
		relax()

		var extras = [] as [(a: Int, b: Int)]
		(0 ..< max(1, n / 5)).forEach { _ in
			var pick = nil as (a: Int, b: Int)?
			var worst = 1.8
			(0 ..< n).forEach { i in
				(i + 1 ..< n).forEach { j in
					guard costs[i][j] < .max, net[i][j] < far else { return }
					let detour = Double(net[i][j]) / Double(costs[i][j])
					if detour > worst {
						worst = detour
						pick = (i, j)
					}
				}
			}
			guard let pick else { return }
			extras.append(pick)
			net[pick.a][pick.b] = Int(costs[pick.a][pick.b])
			net[pick.b][pick.a] = net[pick.a][pick.b]
			relax()
		}
		return extras
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

	/// Forts land last, after generation, as defensive rings `.r12` around
	/// `centers` — the defending side's cities.
	/// Only open ground (field/forest/hill) turns into fort, so roads keep
	/// their gaps through the ring and rivers/settlements stay untouched.
	/// At most `level * size / 4` tiles land in total, centers served in
	/// order. No RNG — placement is a pure function of the map and inputs.
	mutating func placeForts(around centers: [XY], level: Int) {
		var budget = level * size / 4
		for center in centers {
			let ring = center.r12
			for i in ring.indices {
				guard budget > 0 else { return }
				switch self[ring[i]] {
				case .field, .forest, .hill:
					self[ring[i]] = .fort
					budget -= 1
				default: break
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
	/// impassable). Returns the path including both endpoints.
	private func shortestPath(
		from start: XY,
		reached: (XY) -> Bool,
		cost: (XY, XY) -> UInt16?
	) -> [XY]? {
		var dist = Map<32, UInt16>(size: size, zero: .max)
		var prev = Map<32, UInt16>(size: size, zero: 0)
		guard let goal = dijkstra(from: start, reached: reached, cost: cost, dist: &dist, prev: &prev)
		else { return nil }

		var path = [goal]
		var head = goal
		while head != start {
			let packed = prev[head]
			guard packed != 0 else { break }
			let idx = Int(packed) - 1
			head = XY(idx % size, idx / size)
			path.append(head)
		}
		return path
	}

	/// Travel cost from `start` to every tile over `stepCost` terrain,
	/// flooded to exhaustion; `.max` = unreachable.
	private func distances(from start: XY) -> Map<32, UInt16> {
		var dist = Map<32, UInt16>(size: size, zero: .max)
		var prev = Map<32, UInt16>(size: size, zero: 0)
		_ = dijkstra(
			from: start,
			reached: { _ in false },
			cost: { from, to in stepCost(to: to, from: from) },
			dist: &dist,
			prev: &prev
		)
		return dist
	}

	/// Core of `shortestPath`/`distances`: relaxes `dist`/`prev` outward
	/// from `start` and returns the first finalized tile satisfying
	/// `reached`, or `nil` once the flood exhausts. Lazy deletion pushes one
	/// heap entry per relaxation — at most the grid's directed edge count,
	/// 3969 for 32×32 — so 4096 never overflows.
	private func dijkstra(
		from start: XY,
		reached: (XY) -> Bool,
		cost: (XY, XY) -> UInt16?,
		dist: inout Map<32, UInt16>,
		prev: inout Map<32, UInt16>
	) -> XY? {
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
			if reached(topL) { return topL }

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
