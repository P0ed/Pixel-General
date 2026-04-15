extension TacticalState {

	func uidAt(_ xy: XY) -> UID? {
		let id = unitsMap[xy]
		return id < 0 ? nil : id
	}

	func unitAt(_ xy: XY) -> Unit? {
		uidAt(xy).map { uid in units[uid.index] }
	}

	func moves(for uid: UID, target: XY? = nil) -> Moves {
		let unit = units[uid.index]
		var mov = Moves(start: position[uid.index], size: map.size)
		if !unit.canMove { return mov }

		let team = unit.country.team
		let air = unit.isAir
		let visible = player.visible

		func enemy(at xy: XY) -> Bool {
			!visible[xy] ? false : unitAt(xy).map { u in
				u.country.team != team && u.isAir == air
			} ?? false
		}

		let r = unit.mov
		mov.moves[position[uid.index]] = r * 2 + 1
		var front = CArray<1024, XY>(head: position[uid.index], tail: .zero)
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
				if enemies < 2 {
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
			units.forEach { i, u in
				if visible[position[i]] { mov.moves[position[i]] = 0 }
			}
		}

		return mov
	}

	mutating func move(unit uid: UID, to position: XY) {
		guard units[uid.index].country == country, units[uid.index].canMove else { return }

		let moves = moves(for: uid, target: position)
		let route = moves.route(to: position)
		guard !route.isEmpty else { return }

		var pos = moves.start
		var interruptor: UID?
		for xy in route.reversed() {
			if let tid = uidAt(xy) {
				let u = units[tid.index]
				if u.country.team != units[uid.index].country.team, !player.visible[self.position[tid.index]] {
					interruptor = unitsMap[xy]
					break
				}
			} else {
				pos = xy
			}
		}
		for xy in route.reversed() {
			xy.circle(2 * Int(units[uid.index].spot)).forEach { xy in
				player.visible[xy] = true
			}
			if xy == pos { break }
		}

		unitsMap[self.position[uid.index]] = -1
		unitsMap[pos] = uid
		self.position[uid.index] = pos
		units[uid.index].ap &= 0b10
		units[uid.index].ent = 0
		if units[uid.index].type == .soft, units[uid.index][.art] {
			units[uid.index].ap &= 0b01
		}

		selectUnit(units[uid.index].hasActions ? uid : .none)
		events.add(.move(uid, moves.start, pos))

		if let interruptor, units[interruptor.index].country.team != units[uid.index].country.team {
			attack(src: uid, dst: interruptor, surprise: true)
		}
	}
}

struct Moves: ~Copyable {
	var start: XY
	var moves: Map<UInt8>

	subscript(_ xy: XY) -> Bool { moves[xy] != 0 }

	func route(to target: XY) -> [XY] {
		moves[target] == 0 ? [] : .make { route in
			var pos = target
			while pos != start {
				route.append(pos)

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
