public enum AI {

	/// Persistent, fixed-capacity state for the deterministic tactical
	/// heuristic. Strategic assignments are rebuilt when the acting country,
	/// turn, or roster membership changes; the visible tactical picture is
	/// refreshed before every action.
	public struct Plan: ~Copyable {
		public var turn: UInt32?
		public var country: Country = .none
		public var rosterSignature: UInt128 = 0
		public var stance: Stance = .balanced
		public var focusTarget: XY?
		public var actionsThisTurn: UInt16 = 0

		public var role: [128 of Role] = .init(repeating: .idle)
		public var target: [128 of XY] = .init(repeating: .zero)
		public var movePriority: [128 of Int16] = .init(repeating: 0)
		public var order: CArray<128, UID> = .init(tail: .none)
		public var skippedMoves: UInt128 = 0

		public var roster: CArray<128, UID> = .init(tail: .none)
		public var enemies: CArray<128, UID> = .init(tail: .none)

		public var ownSettlements: CArray<64, XY> = .init(tail: .zero)
		public var alliedSettlements: CArray<64, XY> = .init(tail: .zero)
		/// Hostile settlements only. The historical name stays source-compatible.
		public var enemySettlements: CArray<64, XY> = .init(tail: .zero)

		@frozen public enum Stance: UInt8 {
			case balanced
			case defendSurvival
			case attackSurvival

			/// Units at or below this HP retreat to a haven when the plan
			/// is built.
			var retreatHP: UInt8 {
				switch self {
				case .defendSurvival: 7
				case .balanced: 4
				case .attackSurvival: 3
				}
			}

			/// `criticalResupply` triggers at or below this HP — it tracks
			/// `retreatHP` from above so a unit refits before it must run.
			var resupplyHP: UInt8 {
				switch self {
				case .defendSurvival: 9
				case .balanced: 5
				case .attackSurvival: 4
				}
			}
		}

		@frozen public enum Role: UInt8 {
			case idle
			case retreat
			case defend
			case hunt
			case attack
			case support
		}

		public init() {}
	}

	public static var heuristic: (borrowing TacticalSim) -> TacticalAction? {
		var plan = Plan()
		return { sim in sim.run(ai: &plan) }
	}

	public static func lstm(_ weights: LSTMWeights?) -> (borrowing TacticalSim) -> TacticalAction? {
		guard let weights else { return heuristic }
		var policies = [Int: LSTMPolicy]()
		return { sim in
			let seat = sim.playerIndex
			if policies[seat] == nil { policies[seat] = LSTMPolicy(weights: weights) }
			return policies[seat]!.action(for: sim)
		}
	}
}

extension TacticalSim {

	// MARK: - Entry point

	/// Returns one legal deterministic action without mutating the sim or its
	/// random stream. Action order is deliberately reactive: save a critical
	/// unit while it is still untouched, take the best shot on the whole board,
	/// handle transport, execute the highest-priority move, then buy only after
	/// deployment tiles have cleared.
	public func run(ai: inout AI.Plan) -> TacticalAction {
		let signature = refresh(&ai)
		let turnChanged = ai.turn != turn
		if turnChanged { ai.actionsThisTurn = 0 }
		if turnChanged || ai.rosterSignature != signature {
			buildPlan(&ai, signature: signature)
		}
		guard ai.actionsThisTurn < 256 else { return .end }
		ai.actionsThisTurn += 1

		if let action = criticalResupply(ai) { return action }
		if let action = bestAttack(ai) { return action }
		if let action = disembark(ai) { return action }
		if let action = embark(ai) { return action }
		if let action = bestMove(&ai) { return action }
		if let action = purchase(ai) { return action }
		return .end
	}

	// MARK: - Strategic plan

	/// Refresh all information that can change during a turn. Enemy entries are
	/// strictly visible; settlement control is public game state. The returned
	/// bit set is the acting country's current roster membership signature.
	private func refresh(_ ai: inout AI.Plan) -> UInt128 {
		let acting = country
		var signature: UInt128 = 0xcbf29ce484222325
		ai.roster.erase()
		ai.enemies.erase()
		ai.ownSettlements.erase()
		ai.alliedSettlements.erase()
		ai.enemySettlements.erase()

		units.forEachAlive { i, u in
			if u.country == acting {
				ai.roster.add(i.uid)
				let identity = UInt128(i + 1)
					| UInt128(u.model.rawValue) << 8
					| UInt128(u.bits.rawValue) << 16
				signature = (signature ^ identity) &* 0x100000001b3
			} else if !offMap(unit: i.uid), isVisible(i.uid), u.country.team != acting.team {
				ai.enemies.add(i.uid)
			}
		}

		// Generated villages can push a bucket above 64. Truncation is stable
		// because SetXY walks in row-major order.
		settlements.forEach { xy in
			let owner = control[xy]
			if owner == acting {
				if !ai.ownSettlements.isFull { ai.ownSettlements.add(xy) }
			} else if owner.team == acting.team {
				if !ai.alliedSettlements.isFull { ai.alliedSettlements.add(xy) }
			} else if !ai.enemySettlements.isFull {
				ai.enemySettlements.add(xy)
			}
		}
		return signature
	}

	private func buildPlan(_ ai: inout AI.Plan, signature: UInt128) {
		ai.turn = turn
		ai.country = country
		ai.rosterSignature = signature
		ai.stance = strategicStance
		ai.focusTarget = nil
		ai.role = .init(repeating: .idle)
		ai.target = .init(repeating: .zero)
		ai.movePriority = .init(repeating: 0)
		ai.order.erase()
		ai.skippedMoves = 0

		guard !ai.roster.isEmpty else { return }

		// Visible pressure per owned settlement, computed once for the whole
		// rebuild — the survival focus and the garrison assignment both read it.
		var pressures: [64 of Int] = .init(repeating: 0)
		for i in ai.ownSettlements.indices {
			pressures[i] = threat(at: ai.ownSettlements[i], from: ai.enemies)
		}
		ai.focusTarget = strategicFocus(ai, pressures: pressures)

		var claimed: UInt128 = 0

		// Broken units get a supply-compatible haven. Air can repair only at
		// an owned airfield; ground can use any owned settlement, including one.
		let retreatHP = ai.stance.retreatHP
		ai.roster.forEach { _, uid in
			let u = units[uid]
			guard u.hp <= retreatHP || (u.maxAmmo > 0 && u.ammo == 0),
				  let haven = nearestCompatibleHaven(for: uid, ai)
			else { return }
			ai.role[uid.index] = .retreat
			ai.target[uid.index] = haven
			ai.movePriority[uid.index] = 5_000
			claimed |= bit(uid)
		}

		// Assign garrisons by visible pressure, highest pressure first. A
		// survival defender also screens its strategic focus in a quiet sector.
		var visited: UInt64 = 0
		while visited.nonzeroBitCount < ai.ownSettlements.count {
			var pick = -1
			var pickScore = Int.min
			for i in ai.ownSettlements.indices where visited & (UInt64(1) << i) == 0 {
				let xy = ai.ownSettlements[i]
				var score = pressures[i] * 100 + Int(map[xy].income) * 8
				if ai.focusTarget == xy { score += 500 }
				if score > pickScore { pickScore = score; pick = i }
			}
			guard pick >= 0 else { break }
			visited |= UInt64(1) << pick

			let city = ai.ownSettlements[pick]
			let pressure = pressures[pick]
			let quietSurvivalFocus = ai.stance == .defendSurvival && ai.focusTarget == city
			guard pressure > 0 || quietSurvivalFocus else { continue }
			let need = min(3, max(1, 1 + pressure / 22 + (quietSurvivalFocus ? 1 : 0)))

			for _ in 0 ..< need {
				var defender: UID = .none
				var best = Int.max
				ai.roster.forEach { _, uid in
					guard claimed & bit(uid) == 0 else { return }
					let u = units[uid]
					guard canGarrison(u), !offMap(unit: uid) else { return }
					let d = position[uid].stepDistance(to: city)
					let value = d * 8 + garrisonPriority(u)
					if value < best { best = value; defender = uid }
				}
				guard defender != .none else { break }
				ai.role[defender.index] = .defend
				ai.target[defender.index] = city
				ai.movePriority[defender.index] = Int16(clamping: 4_000 + pressure)
				claimed |= bit(defender)
			}
		}

		// Allocate combat units across scored hostile objectives. A load penalty
		// spreads the force without losing concentration on the main focus.
		var loads: [64 of UInt8] = .init(repeating: 0)
		ai.roster.forEach { _, uid in
			guard claimed & bit(uid) == 0, units[uid].type != .supply else { return }
			let u = units[uid]
			let objective = offensiveObjective(for: uid, loads: loads, ai: ai)
			if let objective {
				ai.target[uid.index] = ai.enemySettlements[objective]
				loads[objective].increment(by: 1)
			} else if let enemy = nearestVisibleEnemy(to: position[uid], ai) {
				ai.target[uid.index] = position[enemy]
			} else {
				ai.target[uid.index] = position[uid]
			}
			ai.role[uid.index] = u.isArt || u.isAA || u.isAir ? .hunt : .attack
			let base = ai.role[uid.index] == .hunt ? 3_000 : 2_500
			let urgency = ai.stance == .attackSurvival ? deadlineUrgency * 120 : 0
			ai.movePriority[uid.index] = Int16(clamping: base + urgency)
			claimed |= bit(uid)
		}

		// Supply units trail a real combat anchor, never an arbitrary city.
		ai.roster.forEach { _, uid in
			guard claimed & bit(uid) == 0 else { return }
			let anchor = nearestCombatAnchor(to: position[uid], excluding: uid, ai: ai)
			ai.role[uid.index] = .support
			ai.target[uid.index] = anchor.map { position[$0] }
				?? ai.focusTarget ?? position[uid]
			ai.movePriority[uid.index] = 1_500
		}

		// Fixed-capacity insertion sort: priority descending, UID ascending.
		for i in ai.roster.indices {
			insertInOrder(ai.roster[i], into: &ai)
		}
	}

	private var strategicStance: AI.Plan.Stance {
		switch objective {
		case .none: .balanced
		case .survive(let team, _): country.team == team ? .defendSurvival : .attackSurvival
		}
	}

	private var deadlineUrgency: Int {
		guard case let .survive(team, deadline) = objective, country.team != team else { return 0 }
		let remaining = max(0, Int(deadline) - day)
		return remaining <= 3 ? 4 : remaining <= 7 ? 3 : remaining <= 14 ? 2 : 1
	}

	private func bit(_ uid: UID) -> UInt128 { UInt128(1) << uid.rawValue }

	private func canGarrison(_ u: Unit) -> Bool {
		!u.isAir && (u.type == .inf || u.isArmor || u.isAA)
	}

	private func garrisonPriority(_ u: Unit) -> Int {
		u.type == .inf ? 0 : u.isArmor ? 8 : 16
	}

	private func nearestCompatibleHaven(for uid: UID, _ ai: borrowing AI.Plan) -> XY? {
		let u = units[uid]
		let p = position[uid]
		var haven: XY?
		var distance = Int.max
		ai.ownSettlements.forEach { _, xy in
			guard !u.isAir || map[xy] == .airfield else { return }
			let d = p.stepDistance(to: xy)
			if d < distance { distance = d; haven = xy }
		}
		return haven
	}

	private func strategicFocus(_ ai: borrowing AI.Plan, pressures: borrowing [64 of Int]) -> XY? {
		if ai.stance == .defendSurvival {
			var focus: XY?
			var score = Int.min
			for i in ai.ownSettlements.indices {
				let xy = ai.ownSettlements[i]
				let s = pressures[i] * 100 + Int(map[xy].income) * 12
				if s > score { score = s; focus = xy }
			}
			return focus
		}

		var focus: XY?
		var score = Int.min
		ai.enemySettlements.forEach { _, xy in
			var nearest = Int.max
			ai.roster.forEach { _, uid in
				guard !units[uid].isAir, !offMap(unit: uid) else { return }
				nearest = min(nearest, position[uid].stepDistance(to: xy))
			}
			let urgency = ai.stance == .attackSurvival ? 500 + deadlineUrgency * 100 : 0
			let s = Int(map[xy].income) * 30 + urgency - min(nearest, 100) * 6
			if s > score { score = s; focus = xy }
		}
		return focus
	}

	private func offensiveObjective(
		for uid: UID,
		loads: borrowing [64 of UInt8],
		ai: borrowing AI.Plan
	) -> Int? {
		guard !ai.enemySettlements.isEmpty else { return nil }
		let p = position[uid]
		var best = 0
		var bestScore = Int.min
		for i in ai.enemySettlements.indices {
			let xy = ai.enemySettlements[i]
			var score = Int(map[xy].income) * 26 - p.stepDistance(to: xy) * 8
			score -= Int(loads[i]) * (ai.stance == .attackSurvival ? 90 : 150)
			if ai.focusTarget == xy { score += ai.stance == .attackSurvival ? 700 : 350 }
			if score > bestScore { bestScore = score; best = i }
		}
		return best
	}

	private func insertInOrder(_ uid: UID, into ai: inout AI.Plan) {
		ai.order.add(uid)
		var i = ai.order.count - 1
		while i > 0 {
			let a = ai.order[i]
			let b = ai.order[i - 1]
			let pa = ai.movePriority[a.index]
			let pb = ai.movePriority[b.index]
			guard pa > pb || (pa == pb && a.rawValue < b.rawValue) else { break }
			ai.order.swapAt(i, i - 1)
			i -= 1
		}
	}

	private func threat(at xy: XY, from enemies: borrowing CArray<128, UID>) -> Int {
		var result = 0
		enemies.forEach { _, uid in
			let e = units[uid]
			guard !e.isAir else { return }
			let reach = Int(e.mov) * 2 + 1 + Int(e.rng) * 2 + 1
			if position[uid].stepDistance(to: xy) <= reach + 2 {
				result += Int(e.softAtk) + Int(e.hardAtk) + Int(e.ini) + 4
			}
		}
		return result
	}

	private func nearestVisibleEnemy(to p: XY, _ ai: borrowing AI.Plan) -> UID? {
		ai.enemies.min { p.stepDistance(to: position[$0]) < p.stepDistance(to: position[$1]) }
	}

	private func nearestCombatAnchor(
		to p: XY,
		excluding excluded: UID,
		ai: borrowing AI.Plan
	) -> UID? {
		var best: UID?
		var distance = Int.max
		ai.roster.forEach { _, uid in
			guard uid != excluded, !offMap(unit: uid), units[uid].type != .supply,
				  ai.role[uid.index] != .retreat
			else { return }
			let d = p.stepDistance(to: position[uid])
			if d < distance { distance = d; best = uid }
		}
		return best
	}

	// MARK: - Critical resupply

	private func criticalResupply(_ ai: borrowing AI.Plan) -> TacticalAction? {
		var best: UID = .none
		var bestScore = 0
		let resupplyHP = ai.stance.resupplyHP
		ai.roster.forEach { _, uid in
			let u = units[uid]
			guard canResupply(unit: uid) else { return }
			let empty = u.maxAmmo > 0 && u.ammo == 0
			guard u.hp <= resupplyHP || empty else { return }
			var score = Int(u.maxHP - u.hp) * (ai.stance == .defendSurvival ? 30 : 20)
			score += empty ? 180 + Int(u.maxAmmo) * 8 : 0
			if ai.role[uid.index] == .retreat { score += 40 }
			if score > bestScore { bestScore = score; best = uid }
		}
		return best == .none ? nil : .resupply(best)
	}

	// MARK: - Combat

	/// One global own-unit × visible-enemy scan. The score prices expected value
	/// removed and expected losses, then adds objective, focus-fire, and danger
	/// terms. Strict `>` preserves ascending UID order as the final tie-break.
	private func bestAttack(_ ai: borrowing AI.Plan) -> TacticalAction? {
		var bestSource: UID = .none
		var bestTarget: UID = .none
		var bestScore = Int.min

		ai.roster.forEach { _, uid in
			guard !offMap(unit: uid), units[uid].canAttack, units[uid].ammo > 0 else { return }
			ai.enemies.forEach { _, tid in
				guard canAttack(src: uid, dst: tid) else { return }
				let damage = estimateDamage(attacker: uid, defender: tid, visibleOnly: true)
				guard damage > 0 else { return }
				let score = attackScore(uid, tid, damage: damage, ai: ai)
				if score > bestScore {
					bestScore = score
					bestSource = uid
					bestTarget = tid
				}
			}
		}

		guard bestSource != .none else { return nil }
		// Survival defenders decline a visibly losing trade unless it protects
		// a friendly settlement. Other stances take any positive-value shot.
		let floor = ai.stance == .attackSurvival && deadlineUrgency >= 3 ? -2_000 : 0
		return bestScore >= floor ? .attack(bestSource, bestTarget) : nil
	}

	private func attackScore(
		_ uid: UID,
		_ tid: UID,
		damage: UInt8,
		ai: borrowing AI.Plan
	) -> Int {
		let u = units[uid]
		let target = units[tid]
		let targetXY = position[tid]
		let removedHP = min(damage, target.hp)
		let removedValue = Int(removedHP) * Int(target.cost) / Int(target.maxHP)
		let kill = damage >= target.hp

		var counterDamage: UInt8 = 0
		if unitCanHit(tid, uid), !u.isArt || target.isArt {
			counterDamage = estimateDamage(attacker: tid, defender: uid, visibleOnly: true)
		}

		var supportDamage: UInt8 = 0
		if !u.isAir, !target.isAir, !u.isArt,
		   let support = artSupport(defender: tid, attacker: uid, visibleOnly: true)
		{
			supportDamage = estimateDamage(attacker: support, defender: uid, defMod: 0, visibleOnly: true)
		} else if u.isAir, !target.isAA,
				  let support = aaSupport(defender: tid, attacker: uid, visibleOnly: true)
		{
			supportDamage = estimateDamage(attacker: support, defender: uid, defMod: 0, visibleOnly: true)
		}

		let ownDamage = min(Int(u.hp), Int(counterDamage) + Int(supportDamage))
		let ownLoss = ownDamage * Int(u.cost) / Int(u.maxHP)
		let lossWeight = switch ai.stance {
		case .defendSurvival: 28
		case .balanced: 17
		case .attackSurvival: max(7, 17 - deadlineUrgency * 2)
		}

		var score = removedValue * 24 - ownLoss * lossWeight
		if kill { score += Int(target.cost) * 9 }
		// Wounded targets invite coordinated focus fire; the kill term then
		// makes the final shot much more valuable than spreading damage.
		score += Int(target.maxHP - target.hp) * Int(target.cost) / 3
		score += (Int(target.atk(u)) + Int(target.ini) + Int(target.rng) * 3) * 18

		if target.isArt { score += Int(target.cost) * 3 }
		if target.isAA, u.isAir { score += Int(u.cost) * 4 }
		if target.type == .supply { score += Int(target.cost) * 2 }
		if target.ammo == 0 { score += Int(target.cost) }
		if ai.focusTarget == targetXY { score += Int(target.cost) * 4 }

		if map[targetXY].isSettlement {
			if control[targetXY].team == u.country.team {
				score += Int(target.cost) * 6
			} else {
				score += Int(target.cost) * (ai.stance == .attackSurvival ? 5 : 3)
			}
		}
		if supportDamage >= u.hp { score -= Int(u.cost) * 20 }
		return score
	}

	// MARK: - Transport

	private func disembark(_ ai: borrowing AI.Plan) -> TacticalAction? {
		var bestTransport: UID = .none
		var bestTile = XY.zero
		var bestScore = Int.min

		ai.roster.forEach { _, transport in
			let cargoID = cargo[transport.index]
			guard cargoID != .none, !offMap(unit: transport), units[transport][.transport] else { return }
			let goal = ai.target[cargoID.index]
			let close = position[transport].stepDistance(to: goal) <= 7
			let n4 = position[transport].n4
			for i in n4.indices where canDisembark(unit: transport, to: n4[i]) {
				let xy = n4[i]
				let capture = map[xy].isSettlement && control[xy].team != country.team
				guard close || capture else { continue }
				var score = -xy.stepDistance(to: goal) * 20
				if capture { score += 5_000 }
				score += movementTileScore(xy, for: cargoID, toward: goal, ai: ai)
				if score > bestScore {
					bestScore = score
					bestTransport = transport
					bestTile = xy
				}
			}
		}
		return bestTransport == .none ? nil : .disembark(bestTransport, bestTile)
	}

	private func embark(_ ai: borrowing AI.Plan) -> TacticalAction? {
		for i in ai.order.indices {
			let uid = ai.order[i]
			let u = units[uid]
			guard !offMap(unit: uid), u.transportable, u.canMove, cargo[uid] == .none else { continue }
			let goal = ai.target[uid.index]
			guard position[uid].stepDistance(to: goal) >= Int(u.mov) * 6 + 5 else { continue }
			let n4 = position[uid].n4
			for k in n4.indices {
				let transport = unitsMap[n4[k]]
				if transport != .none, canEmbark(unit: uid, transport: transport) {
					return .embark(uid, transport)
				}
			}
		}
		return nil
	}

	// MARK: - Movement

	/// Selects from the cached order before doing pathfinding, so an action pays
	/// for one BFS: the one mover it actually considers.
	private func bestMove(_ ai: inout AI.Plan) -> TacticalAction? {
		for i in ai.order.indices {
			let uid = ai.order[i]
			guard ai.skippedMoves & bit(uid) == 0, units[uid].canMove, !offMap(unit: uid) else { continue }
			let p = position[uid]
			if !units[uid].isAir, map[p].isSettlement, control[p].team != country.team { continue }
			let role = ai.role[uid.index]
			if role == .support, let anchor = nearestCombatAnchor(to: p, excluding: uid, ai: ai),
			   p.stepDistance(to: position[anchor]) <= 3 { continue }
			let target = movementTarget(for: uid, ai)
			if (role == .retreat || role == .defend) && p == target { continue }

			if let action = pickMove(uid, toward: target, ai: ai) { return action }
			ai.skippedMoves |= bit(uid)
			return nil
		}
		return nil
	}

	private func movementTarget(for uid: UID, _ ai: borrowing AI.Plan) -> XY {
		let u = units[uid]
		let p = position[uid]
		if u.isAir, u.ammo == 0, let airfield = nearestOwnAirfield(to: p, ai) {
			return airfield
		}
		if ai.role[uid.index] == .support,
		   let anchor = nearestCombatAnchor(to: p, excluding: uid, ai: ai)
		{
			return position[anchor]
		}
		return ai.target[uid.index]
	}

	private func nearestOwnAirfield(to p: XY, _ ai: borrowing AI.Plan) -> XY? {
		var best: XY?
		var distance = Int.max
		ai.ownSettlements.forEach { _, xy in
			guard map[xy] == .airfield else { return }
			let d = p.stepDistance(to: xy)
			if d < distance { distance = d; best = xy }
		}
		return best
	}

	private func pickMove(_ uid: UID, toward target: XY, ai: borrowing AI.Plan) -> TacticalAction? {
		let moves = moves(for: uid)
		let here = position[uid]
		var best: XY?
		var bestScore = Int.min
		for xy in moves.moves.indices where moves.moves[xy] > 0 && xy != here {
			let score = movementTileScore(xy, for: uid, toward: target, ai: ai)
			if score > bestScore { bestScore = score; best = xy }
		}
		return best.map { .move(uid, $0) }
	}

	private func movementTileScore(
		_ xy: XY,
		for uid: UID,
		toward target: XY,
		ai: borrowing AI.Plan
	) -> Int {
		let u = units[uid]
		let here = position[uid]
		let team = u.country.team
		let role = ai.role[uid.index]
		let defensive = role == .retreat || role == .defend || role == .support
		let oldDistance = here.stepDistance(to: target)
		let newDistance = xy.stepDistance(to: target)
		var score = (oldDistance - newDistance) * (defensive ? 22 : 34) - newDistance * 5
		if xy == target { score += 450 }

		if !u.isAir {
			score += Int(map[xy].baseEntrenchment) * (defensive ? 16 : 7)
			score += Int(map[xy].def(u.type)) * (defensive ? 8 : 4)
		}

		// One enemy pass shares the tile distance between both terms. A unit
		// that may fire after moving values actual weapon range, not only
		// adjacency: killable and dangerous targets pull it into firing
		// position, while enemy reach onto the tile accumulates danger.
		let mayFire = u.canAttackAfterMove && u.ap > 0 && u.ammo > 0
		let uRange = Int(u.rng) * 2 + 1
		var danger = 0
		ai.enemies.forEach { _, enemy in
			let e = units[enemy]
			let d = xy.stepDistance(to: position[enemy])
			if mayFire, d <= uRange, u.atk(e) > 0 {
				score += Int(u.atk(e)) * 24 + Int(e.cost) / 5
				if e.hp <= 4 { score += Int(e.cost) / 2 }
			}
			guard e.atk(u) > 0 else { return }
			let range = Int(e.rng) * 2 + 1
			if d <= range {
				danger += Int(e.atk(u)) * 4 + Int(e.ini)
			} else if e.canAttackAfterMove, e.mp > 0, d <= range + Int(e.mov) * 2 + 1 {
				danger += Int(e.atk(u)) * 2
			}
		}

		let n8 = xy.n8
		var congestion = 0
		for i in n8.indices {
			let other = unitsMap[n8[i]]
			guard other != .none, other != uid, isVisible(other) else { continue }
			let friend = units[other]
			guard friend.country.team == team else { continue }
			congestion += 1
			if friend.isArt { score += 28 }
			if friend.isAA, !u.isAA { score += u.isAir ? 42 : 22 }
			if friend.type == .supply { score += 38 }
		}
		score -= congestion * 12
		let dangerWeight = switch ai.stance {
		case .defendSurvival: defensive ? 7 : 5
		case .balanced: defensive ? 5 : 3
		case .attackSurvival: max(1, 4 - deadlineUrgency / 2)
		}
		score -= danger * dangerWeight

		if map[xy].isSettlement {
			if control[xy].team != team {
				// Air cannot capture and must never plug the tile a ground unit needs.
				score += u.isAir ? -20_000 : 6_000 + Int(map[xy].income) * 20
			} else if u.isAir {
				// Friendly airfields are useful, but an idle aircraft should not
				// casually close a deployment tile.
				score += map[xy] == .airfield ? 35 : -500
			}
		}
		return score
	}

	// MARK: - Purchasing

	private func purchase(_ ai: borrowing AI.Plan) -> TacticalAction? {
		let reserve: UInt16 = ai.stance == .attackSurvival && deadlineUrgency >= 3 ? 0 : 0x100
		guard player.prestige > reserve else { return nil }

		var core = 0
		var ground = 0
		var capture = 0
		var artillery = 0
		var aa = 0
		var supply = 0
		var enemyAir = 0
		var enemyArmor = 0
		ai.roster.forEach { _, uid in
			let u = units[uid]
			if !u[.aux] { core += 1 }
			if !u.isAir { ground += 1 }
			if u.type == .inf || u.isArmor { capture += 1 }
			if u.isArt { artillery += 1 }
			if u.isAA { aa += 1 }
			if u.type == .supply { supply += 1 }
		}
		ai.enemies.forEach { _, uid in
			enemyAir += units[uid].isAir ? 1 : 0
			enemyArmor += units[uid].isArmor ? 1 : 0
		}
		guard core < 16 else { return nil }

		var bestSpot = XY.zero
		var bestSlot = -1
		var bestScore = Int.min
		settlements.forEach { xy in
			guard control[xy] == country, unitsMap[xy] == .none else { return }
			let shop = shopUnits(at: xy)
			guard !shop.isEmpty else { return }
			var locationScore = threat(at: xy, from: ai.enemies) * (ai.stance == .defendSurvival ? 5 : 2)
			if let focus = ai.focusTarget { locationScore -= xy.stepDistance(to: focus) * 5 }
			for slot in shop.indices {
				let template = shop[slot]
				guard template.cost + reserve <= player.prestige else { continue }
				let score = locationScore + purchaseScore(
					template,
					ground: ground, capture: capture, artillery: artillery,
					aa: aa, supply: supply, enemyAir: enemyAir, enemyArmor: enemyArmor,
					stance: ai.stance
				)
				if score > bestScore {
					bestScore = score
					bestSpot = xy
					bestSlot = slot
				}
			}
		}
		return bestSlot < 0 ? nil : .purchase(bestSlot, bestSpot)
	}

	private func purchaseScore(
		_ u: Unit,
		ground: Int,
		capture: Int,
		artillery: Int,
		aa: Int,
		supply: Int,
		enemyAir: Int,
		enemyArmor: Int,
		stance: AI.Plan.Stance
	) -> Int {
		var score = Int(u.softAtk) * 8 + Int(u.hardAtk) * (enemyArmor > 0 ? 11 : 7)
		score += Int(u.airAtk) * (enemyAir > 0 ? 14 : 4)
		score += Int(u.groundDef) * 5 + Int(u.airDef) * (enemyAir > 0 ? 7 : 4)
		score += Int(u.ini) * 7 + Int(u.mov) * 6 + Int(u.rng) * 10
		score -= Int(u.cost) / 5

		if u.type == .supply, supply * 6 < max(ground, 1) { score += 260 }
		if u.isArt, artillery * 4 < max(ground, 1) { score += 230 }
		if u.isAA, aa * 3 < max(enemyAir + 1, 2) { score += enemyAir > 0 ? 300 : 100 }
		if u.type == .inf || u.isArmor, capture * 3 < max(ground * 2, 3) { score += 220 }

		switch stance {
		case .defendSurvival:
			if u.type == .inf || u.isArt || u.isAA { score += 80 }
		case .attackSurvival:
			if u.type == .inf || u.isArmor { score += 100 + Int(u.mov) * 20 }
		case .balanced:
			break
		}
		return score
	}
}
