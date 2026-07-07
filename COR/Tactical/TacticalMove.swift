public extension TacticalSim {

	func uidAt(_ xy: XY) -> UID? {
		let id = unitsMap[xy]
		return id == .none ? nil : id
	}

	func unitAt(_ xy: XY) -> Unit? {
		uidAt(xy).map { uid in units[uid] }
	}

	func moves(for uid: UID, target: XY? = nil) -> Moves {
		let unit = units[uid]
		var mov = Moves(start: position[uid], size: map.size)
		if !unit.canMove { return mov }

		let team = unit.country.team
		let air = unit.isAir
		let visible = vision[playerIndex]

		func enemy(at xy: XY) -> Bool {
			!visible[xy] ? false : unitAt(xy).map { u in
				u.country.team != team && u.isAir == air
			} ?? false
		}

		let r = unit.mov
		mov.moves[position[uid]] = r * 2 + 1
		var front = CArray<1024, XY>(head: position[uid], tail: .zero)
		var next = CArray<1024, XY>(tail: .zero)

		for _ in 0 ..< r where !front.isEmpty {
			front.forEach { _, from in
				let mp = mov.moves[from]
				let n4 = from.n4
				let enemies = n4.reduce(into: 0 as UInt8) { r, xy in
					if enemy(at: xy) { r += 1 }
				}

				for i in n4.indices {
					let xy = n4[i]
					if mov[xy] { continue }
					if enemy(at: xy) { continue }

					let moveCost = map[xy].moveCost(unit) * 2 + enemies
					if moveCost + 1 <= mp {
						mov.moves[xy] = mp - moveCost
						if mp - moveCost != 1 { next.add(xy) }
					}
				}
				if enemies == 0 {
					let x4 = from.x4
					for i in x4.indices {
						let xy = x4[i]
						if mov[xy] { continue }
						if enemy(at: xy) { continue }

						let moveCost = map[xy].moveCost(unit) * 3 + enemies
						if moveCost + 1 <= mp {
							mov.moves[xy] = mp - moveCost
							if mp - moveCost != 1 { next.add(xy) }
						}
					}
				}
			}
			front.erase()
			front.add(next)
			next.erase()
		}
		if target == nil {
			units.forEachAlive { i, u in
				if !offMap(unit: i.uid), visible[position[i]] { mov.moves[position[i]] = 0 }
			}
		}

		return mov
	}

	func canMove(unit uid: UID) -> Bool {
		units[uid].country == country && units[uid].canMove && !offMap(unit: uid)
	}

	mutating func move(unit uid: UID, to target: XY, into events: inout [TacticalEvent]) {
		guard canMove(unit: uid) else { return }

		let moves = moves(for: uid, target: target)
		let route = moves.route(to: target)
		guard !route.isEmpty else { return }

		var pos = moves.start
		var interruptor: UID = .none
		for k in stride(from: route.count - 1, through: 0, by: -1) {
			let xy = route[k]
			if let tid = uidAt(xy) {
				let u = units[tid]
				if u.country.team != units[uid].country.team, !vision[playerIndex][position[tid.index]] {
					interruptor = unitsMap[xy]
					break
				}
			} else {
				pos = xy
			}
		}
		for k in stride(from: route.count - 1, through: 0, by: -1) {
			vision[playerIndex].formUnion(vision(at: route[k], spot: units[uid].spot))
			if route[k] == pos { break }
		}

		place(uid, at: pos)
		units[uid].mp.decrement()
		units[uid].ent = 0
		if !units[uid].canAttackAfterMove {
			units[uid].ap = 0
		}

		if pos != moves.start {
			var path = CArray<16, XY>(head: moves.start, tail: .zero)
			for k in stride(from: route.count - 1, through: 0, by: -1) {
				path.add(route[k])
				if route[k] == pos { break }
			}
			events.append(.move(uid, Path(count: path.count, path: path.mem)))
			if cargo[uid.index] != .none {
				events.append(.move(cargo[uid.index], Path(count: path.count, path: path.mem)))
			}
		}

		if interruptor != .none, units[interruptor].country.team != units[uid].country.team {
			attack(src: uid, dst: interruptor, surprise: true, into: &events)
		}
	}
}

/// Reachable tiles of one unit, as BFS budget leftovers per tile.
///
/// Consumers scan `moves.indices` in its fixed row-major order and break score
/// ties by iteration order — deliberately never through a `Set<XY>`: Swift
/// seeds `Set`/`Dictionary` hashing with a per-process random value, so a set
/// walk would make the battle (and `TacticalPerformanceTests`)
/// non-deterministic across launches.
public struct Moves: ~Copyable {
	public var start: XY
	public var moves: Map<32, UInt8>

	public subscript(_ xy: XY) -> Bool { moves[xy] != 0 }

	/// The path to `target`, ordered target → start (exclusive). Empty when
	/// `target` is unreachable.
	public func route(to target: XY) -> CArray<16, XY> {
		var route = CArray<16, XY>(tail: .zero)
		guard moves[target] != 0 else { return route }

		var pos = target
		while pos != start {
			route.add(pos)

			if route.count > 0xF {
				route.erase(); return route
			}

			let n8 = pos.n8
			var next: XY? = nil
			for i in n8.indices where moves[n8[i]] > 0 {
				if next == nil || moves[next!] < moves[n8[i]] { next = n8[i] }
			}
			if let next { pos = next } else {
				route.erase(); return route
			}
		}
		return route
	}
}

public extension Moves {

	init(start: XY, size: Int) {
		self.start = start
		moves = .init(size: size, zero: 0)
	}

	var setXY: SetXY {
		.make { set in
			for xy in moves.indices where moves[xy] > 0 {
				set[xy] = true
			}
		}
	}

	var hasMoves: Bool {
		for xy in moves.indices where moves[xy] > 0 && xy != start {
			return true
		}
		return false
	}
}

public struct Path {
	public var count: Int
	public var path: [16 of XY]

	public init(count: Int, path: [16 of XY]) {
		self.count = count
		self.path = path
	}

	public subscript(i: Int) -> XY {
		path[i]
	}

	public func contains(_ xy: XY) -> Bool {
		contains { $0 == xy }
	}

	public func contains(_ predicate: (XY) -> Bool) -> Bool {
		for i in 0..<count {
			if predicate(path[i]) {
				return true
			}
		}
		return false
	}

	public func reduce<Result>(
		into result: Result,
		_ fold: (inout Result, XY) -> Void
	) -> Result {
		var result = result
		for i in 0..<count {
			fold(&result, path[i])
		}
		return result
	}
}
