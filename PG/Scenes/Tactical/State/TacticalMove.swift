extension TacticalState {

	func moves(for unit: Unit, target: XY? = nil) -> Moves {
		var mov = Moves(start: unit.position, size: map.size)
		if !unit.canMove { return mov }

		let team = unit.country.team
		let air = unit.stats.isAir
		let visible = player.visible

		func enemy(at xy: XY) -> Bool {
			!visible[xy] ? false : units[xy].map { _, u in
				u.country.team != team && u.stats.isAir == air
			} ?? false
		}

		mov.moves[unit.position] = unit.stats.mov * 2 + 1
		print("mov started at \(mov.start) \(mov.moves[mov.start])")
		var front: [XY] = [unit.position]
		for _ in 0 ..< unit.stats.mov where !front.isEmpty {
			front = front.flatMap { from in
				let mp = mov.moves[from]
				let n4 = from.n4
				let enemies = n4.reduce(into: 0 as UInt8) { r, xy in
					if enemy(at: xy) { r += 1 }
				}
				var next = [] as [XY]

				for i in n4.indices {
					let xy = n4[i]
					if mov[xy] { continue }
					if enemy(at: xy) { continue }

					let moveCost = map[xy].moveCost(unit.stats) * 2 + enemies
					if moveCost + 1 <= mp {
						mov.moves[xy] = mp - moveCost
						print("put d \(xy) \(mov.moves[xy])")
						if mp - moveCost != 1 { next.append(xy) }
					}
				}
				if enemies < 2 {
					let x4 = from.x4
					for i in x4.indices {
						let xy = x4[i]
						if mov[xy] { continue }
						if enemy(at: xy) { continue }

						let moveCost = map[xy].moveCost(unit.stats) * 3 + enemies
						if moveCost + 1 <= mp {
							mov.moves[xy] = mp - moveCost
							print("put x \(xy) \(mov.moves[xy])")
							if mp - moveCost != 1 { next.append(xy) }
						}
					}
				}
				return next
			}
		}
		if target == nil {
			units.forEach { i, u in
				if visible[u.position] { mov.moves[u.position] = 0 }
			}
		}

		return mov
	}

	mutating func move(unit uid: UID, to position: XY) {
		guard units[uid].alive, units[uid].country == country, units[uid].canMove
		else { return }

		let moves = moves(for: units[uid], target: position)
		let route = moves.route(to: position)
		guard !route.isEmpty else { return }

		var pos = moves.start
		var interruptor: UID?
		for xy in route.reversed() {
			if let (i, u) = units[xy] {
				if u.country.team != units[uid].country.team, !player.visible[u.position] {
					interruptor = i
					break
				}
			} else {
				pos = xy
			}
		}

		let distance = units[uid].position.distance(to: pos)
		units[uid].position = pos
		units[uid].stats.mp = 0
		units[uid].stats.ent = 0
		if units[uid].stats.type == .soft, units[uid].stats[.art] {
			units[uid].stats.ap = 0
		}

		player.visible.formUnion(vision(for: units[uid]))
		selectUnit(units[uid].hasActions ? uid : .none)
		events.add(.move(uid, distance))

		if let interruptor,
		   units[interruptor].country.team != units[uid].country.team,
		   units[uid].canAttack
		{ attack(src: uid, dst: interruptor, atkIni: units[uid].stats.stars * 2) }
	}
}

struct Moves: ~Copyable {
	var start: XY
	var moves: Map<UInt8>

	subscript(_ xy: XY) -> Bool { moves[xy] != 0 }

	func route(to target: XY) -> [XY] {
		moves[target] == 0 ? [] : .make { route in
			print("routing:")
			var pos = target
			while pos != start {
				route.append(pos)
				print("\(pos)")

				if route.count > 0xF {
					route = []; return
				}

				if let m = pos.n8
					.compactMap({ moves[$0] > 0 ? $0 : nil })
					.max(by: { a, b in moves[a] < moves[b] })
				{ pos = m } else {
					route = []; return
				}
			}
		}
	}
}

extension Moves {

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

	var set: Set<XY> {
		.make { set in
			for xy in moves.indices where moves[xy] > 0 {
				set.insert(xy)
			}
		}
	}
}
