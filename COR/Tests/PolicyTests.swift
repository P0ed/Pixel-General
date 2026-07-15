import Testing
import Foundation
@testable import COR

/// Test-only sampling helper, kept separate from `D20`'s combat-facing API.
private extension D20 {
	mutating func pick(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
}

/// Contracts of the LSTM policy plumbing (see Docs/AI.md):
/// the observation encoding is fog-correct, and the factored action space
/// (`ActionSpace`) masks exactly the actions `reduce` accepts.
struct PolicyTests {

	private static func makeSim(seed: Int, size: Int = 24) -> TacticalSim {
		TacticalSim(
			players: [
				Player(country: .ger, type: .ai, prestige: .rich, baseLevel: 0),
				Player(country: .usa, type: .ai, prestige: .rich, baseLevel: 0),
			],
			units: .base(.ger) + .aux(.ger) + .base(.usa) + .aux(.usa),
			size: size,
			seed: seed
		)
	}


	// MARK: - SimObservation

	@Test func observationRespectsFog() {
		var sim = Self.makeSim(seed: 3)
		var ai = AI.Plan()

		// Play into the midgame so fog actually hides units.
		for _ in 0 ..< 300 {
			if sim.aliveTeams.nonzeroBitCount <= 1 { break }
			_ = sim.reduce(sim.run(ai: &ai))
		}

		let obs = sim.observation()
		let side = SimObservation.side
		let c = SimObservation.planeCount
		func plane(_ xy: XY, _ p: Int) -> Float { obs.planes[(xy.y * side + xy.x) * c + p] }

		let myTeam = sim.player.country.team
		var friendly = 0
		var enemies = 0

		for y in 0 ..< side {
			for x in 0 ..< side {
				let xy = XY(x, y)
				let onMap = plane(xy, Plane.onMap)
				#expect(onMap == (sim.map.contains(xy) ? 1 : 0))

				// Fog: an enemy in the tensor must be a visible one.
				if plane(xy, Plane.unitEnemy) == 1 {
					#expect(plane(xy, Plane.visible) == 1)
					#expect(sim.vision[sim.playerIndex][xy])
				}
				friendly += plane(xy, Plane.unitFriendly) == 1 ? 1 : 0
				enemies += plane(xy, Plane.unitEnemy) == 1 ? 1 : 0
			}
		}

		// Plane counts match a direct census of the sim.
		let expected = sim.units.reduceAlive(into: (0, 0)) { r, i, u in
			guard !sim.offMap(unit: i.uid) else { return }
			if u.country.team == myTeam {
				r.0 += 1
			} else if sim.vision[sim.playerIndex][sim.position[i]] {
				r.1 += 1
			}
		}
		#expect(friendly == expected.0)
		#expect(enemies == expected.1)
		#expect(friendly > 0)
	}

	// MARK: - Action space

	/// Every action the heuristic AI emits must be representable, legal under
	/// the masks, and survive the head-indices round-trip. This pins the BC
	/// training labels to the mask semantics.
	@Test func heuristicActionsAreLegalAndRoundTrip() {
		var sim = Self.makeSim(seed: 5)
		var ai = AI.Plan()

		var steps = 0
		while steps < 600, sim.aliveTeams.nonzeroBitCount > 1, sim.day <= 16 {
			let action = sim.run(ai: &ai)
			let idx = sim.actionIndices(action)
			guard let idx else {
				Issue.record("heuristic AI emitted an unencodable action: \(action)")
				break
			}

			#expect(sim.action(idx) == action, "round-trip failed for \(action)")

			if idx.kind != .end {
				let masks = sim.actionMasks()
				#expect(masks.kinds[idx.kind.rawValue], "kind \(idx.kind) masked off for \(action)")
				#expect(masks.actors[idx.kind.rawValue][idx.actor], "actor masked off for \(action)")

				switch idx.kind {
				case .move, .embark, .disembark, .attack:
					let targets = sim.targetMask(idx.kind, actor: idx.actor)
					#expect(targets[idx.target], "target masked off for \(action)")
				case .purchase:
					let slots = sim.slotMask(actor: idx.actor)
					#expect(idx.slot >= 0 && idx.slot < ActionSpace.slots && slots[idx.slot], "slot masked off for \(action)")
				case .resupply, .end:
					break
				}
			}

			_ = sim.reduce(action)
			steps += 1
		}
		#expect(steps > 100)
	}

	// MARK: - Weights & policy

	/// `PGW1` must round-trip bit-exactly and reject anything malformed —
	/// a weight file either matches `LSTMWeights.spec` verbatim or fails.
	@Test func weightsRoundTripAndValidate() {
		let a = LSTMWeights.random(seed: 11)
		for (name, shape) in LSTMWeights.spec {
			#expect(a[name].count == shape.reduce(1, *), "bad tensor size for \(name)")
		}
		// Forget-gate bias +1, everything else around zero.
		let H = LSTMWeights.hidden
		#expect(a["lstm.b"][H] == 1 && a["lstm.b"][H - 1] == 0 && a["lstm.b"][2 * H] == 0)

		let data = a.data()
		let b = LSTMWeights(data: data)
		#expect(b != nil)
		#expect(b?.values == a.values)

		#expect(LSTMWeights(data: Data()) == nil)
		#expect(LSTMWeights(data: data.dropLast()) == nil)
		#expect(LSTMWeights(data: data + [0]) == nil)
		var corrupt = data
		corrupt[0] = 0
		#expect(LSTMWeights(data: corrupt) == nil)
	}

	/// An untrained (random-weight) `LSTMPolicy` must already be a lawful
	/// player: every non-`.end` action it emits mutates the state (reducers
	/// no-op on illegal input), and its turns always terminate.
	@Test func randomWeightPolicyPlaysLegally() {
		// The seeds must give a battle that survives past the 20-step floor
		// below with a policy that doesn't just end turns; regenerated maps or
		// an observation-contract change can shift both, so repick either seed
		// if this stalls (weight seed 13 degenerated to always-`.end` when the
		// plane count went 51 → 53).
		var sim = Self.makeSim(seed: 8)
		var policy = LSTMPolicy(weights: .random(seed: 14))
		var ai = AI.Plan()

		var policySteps = 0
		var mutations = 0
		for _ in 0 ..< 400 {
			if sim.aliveTeams.nonzeroBitCount <= 1 { break }
			if policySteps >= 120 { break }

			if sim.playerIndex == 0 {
				let action = policy.action(for: sim)
				let before = encode(sim)
				_ = sim.reduce(action)
				policySteps += 1
				if action != .end {
					#expect(encode(sim) != before, "policy action was a no-op: \(action)")
					mutations += 1
				}
				#expect(policy.lastValue.isFinite)
			} else {
				_ = sim.reduce(sim.run(ai: &ai))
			}
		}

		#expect(policySteps > 20, "battle stalled — policy never got to act")
		#expect(mutations > 0, "policy only ever ended its turn")
	}

	/// A maximally uninformed (random) but mask-respecting policy: every
	/// sampled non-`.end` action must mutate the encoded state — the reducers
	/// no-op on illegal input, so mutation is the legality oracle.
	@Test func maskedRandomActionsAlwaysMutateState() {
		var sim = Self.makeSim(seed: 7)
		var rand = D20(seed: 42)
		var perTurn = 0

		for _ in 0 ..< 400 {
			if sim.aliveTeams.nonzeroBitCount <= 1 { break }

			let masks = sim.actionMasks()
			var pairs: [(ActionSpace.Kind, Int)] = []
			for kind in ActionSpace.Kind.allCases where kind != .end {
				let actors = masks.actors[kind.rawValue]
				for tile in actors.indices where actors[tile] {
					pairs.append((kind, tile))
				}
			}

			// Cap runaway turns (resupply/move chains), then force .end.
			let action: TacticalAction
			if pairs.isEmpty || perTurn > 64 {
				action = .end
			} else {
				let (kind, actor) = pairs[rand.pick(pairs.count)]
				var idx = ActionIndices(kind: kind, actor: actor)
				switch kind {
				case .move, .embark, .disembark, .attack:
					let targets = sim.targetMask(kind, actor: actor)
					let legal = targets.indices.filter { targets[$0] }
					#expect(!legal.isEmpty, "actor masked legal but no target for \(kind)")
					guard !legal.isEmpty else { continue }
					idx.target = legal[rand.pick(legal.count)]
				case .purchase:
					let slots = sim.slotMask(actor: actor)
					let legal = slots.indices.filter { slots[$0] }
					#expect(!legal.isEmpty, "purchase masked legal but no affordable slot")
					guard !legal.isEmpty else { continue }
					idx.slot = legal[rand.pick(legal.count)]
				case .resupply, .end:
					break
				}
				guard let decoded = sim.action(idx) else {
					Issue.record("legal indices failed to decode: \(idx)")
					continue
				}
				action = decoded
			}

			let turnBefore = sim.turn
			let before = encode(sim)
			_ = sim.reduce(action)

			if action != .end {
				#expect(encode(sim) != before, "masked action was a no-op: \(action)")
				perTurn += 1
			} else {
				perTurn = 0
				#expect(sim.turn != turnBefore || sim.aliveTeams.nonzeroBitCount <= 1)
			}
		}
	}

	// MARK: - Heuristic AI

	private static func plannedSim(objective: Objective = .none) -> TacticalSim {
		var map = Map<32, Terrain>(size: 10, zero: .field)
		map[XY(1, 1)] = .city
		map[XY(5, 1)] = .city
		map[XY(8, 8)] = .city
		let players = [
			Player(country: .ger, type: .ai, prestige: .poor),
			Player(country: .fin, type: .ai, prestige: .poor),
			Player(country: .usa, type: .ai, prestige: .poor),
		]
		var units = players.map { Unit(model: .regular, country: $0.country) }
		units.modifyEach { u in u.reset() }
		var sim = TacticalSim(
			map: consume map,
			players: players,
			cities: [(XY(1, 1), .ger), (XY(5, 1), .fin), (XY(8, 8), .usa)],
			units: units
		)
		sim.objective = objective
		sim.vision.modifyEach { v in v = .full }
		return sim
	}

	/// Open-field ger-vs-usa duel: cities placed and controlled as given,
	/// units reset and placed in order (UID = array index), full vision
	/// unless the test punches its own holes.
	private static func duelSim(
		size: Int = 10,
		cities: [(XY, Country)] = [(XY(0, 0), .ger), (XY(9, 9), .usa)],
		units: [COR.Unit],
		at positions: [XY],
		fullVision: Bool = true
	) -> TacticalSim {
		var map = Map<32, Terrain>(size: size, zero: .field)
		for (xy, _) in cities { map[xy] = .city }
		var units = units
		units.modifyEach { u in u.reset() }
		var sim = TacticalSim(
			map: consume map,
			players: [
				Player(country: .ger, type: .ai, prestige: .poor),
				Player(country: .usa, type: .ai, prestige: .poor),
			],
			cities: cities,
			units: units
		)
		for (i, xy) in positions.enumerated() { sim.place(i.uid, at: xy) }
		if fullVision { sim.vision.modifyEach { v in v = .full } }
		return sim
	}

	@Test func alliedSettlementsNeverBecomeHostileObjectives() {
		let sim = Self.plannedSim()
		var ai = AI.Plan()
		_ = sim.run(ai: &ai)

		let hasOwn = ai.ownSettlements.contains(XY(1, 1))
		let hasAlly = ai.alliedSettlements.contains(XY(5, 1))
		let hasEnemy = ai.enemySettlements.contains(XY(8, 8))
		let allyIsEnemy = ai.enemySettlements.contains(XY(5, 1))
		#expect(hasOwn)
		#expect(hasAlly)
		#expect(hasEnemy)
		#expect(!allyIsEnemy)
		#expect(ai.focusTarget != XY(5, 1))
	}

	@Test func survivalObjectiveSelectsDefenderAndAttackerStances() {
		let defender = Self.plannedSim(objective: .survive(.axis, day: 20))
		var defenderAI = AI.Plan()
		_ = defender.run(ai: &defenderAI)
		#expect(defenderAI.stance == .defendSurvival)

		let attacker = Self.plannedSim(objective: .survive(.allies, day: 20))
		var attackerAI = AI.Plan()
		_ = attacker.run(ai: &attackerAI)
		#expect(attackerAI.stance == .attackSurvival)
	}

	@Test func retreatAssignmentsUseCompatibleSupplyHavens() {
		var map = Map<32, Terrain>(size: 10, zero: .field)
		map[XY(1, 1)] = .city
		map[XY(1, 4)] = .airfield
		map[XY(8, 8)] = .city
		let players = [
			Player(country: .ger, type: .ai, prestige: .poor),
			Player(country: .usa, type: .ai, prestige: .poor),
		]
		var ground = Unit(model: .regular, country: .ger)
		var air = Unit(model: .skeldar, country: .ger)
		ground.reset(); air.reset()
		ground.hp = 2; air.hp = 2
		var sim = TacticalSim(
			map: consume map,
			players: players,
			cities: [(XY(1, 1), .ger), (XY(1, 4), .ger), (XY(8, 8), .usa)],
			units: [ground, air]
		)
		let groundID = sim.units.firstMapAlive { i, u in !u.isAir ? i.uid : nil }!
		let airID = sim.units.firstMapAlive { i, u in u.isAir ? i.uid : nil }!
		sim.place(groundID, at: XY(4, 1))
		sim.place(airID, at: XY(4, 4))
		sim.vision.modifyEach { v in v = .full }

		var ai = AI.Plan()
		_ = sim.run(ai: &ai)
		#expect(ai.role[groundID.index] == .retreat)
		#expect(sim.map[ai.target[groundID.index]].isSettlement)
		#expect(ai.role[airID.index] == .retreat)
		#expect(sim.map[ai.target[airID.index]] == .airfield)
	}

	@Test func globalAttackSelectionIsNotBoundToFirstAttacker() {
		let sim = Self.duelSim(
			units: [
				Unit(model: .regular, country: .ger),	// weak
				Unit(model: .m270, country: .ger),		// strong
				Unit(model: .militia, country: .usa),	// target
			],
			at: [XY(4, 3), XY(3, 3), XY(5, 3)]
		)

		var ai = AI.Plan()
		guard case let .attack(source, destination) = sim.run(ai: &ai) else {
			Issue.record("heuristic did not take an available attack")
			return
		}
		#expect(source == 1.uid)
		#expect(destination == 2.uid)
	}

	@Test func attackSelectionFocusesWoundedTargets() {
		var sim = Self.duelSim(
			units: [
				Unit(model: .m270, country: .ger),
				Unit(model: .militia, country: .usa),	// full
				Unit(model: .militia, country: .usa),	// wounded
			],
			at: [XY(3, 3), XY(5, 3), XY(3, 5)]
		)
		sim.units[2.uid].hp = 2

		var ai = AI.Plan()
		guard case let .attack(_, target) = sim.run(ai: &ai) else {
			Issue.record("heuristic did not take an available attack")
			return
		}
		#expect(target == 2.uid)
	}

	@Test func attackSelectionAvoidsVisibleSupportFire() {
		let sim = Self.duelSim(
			units: [
				Unit(model: .f35, country: .ger),
				Unit(model: .militia, country: .usa),	// protected by the patriot
				Unit(model: .militia, country: .usa),	// safe to strike
				Unit(model: .patriot, country: .usa),
			],
			at: [XY(3, 3), XY(5, 3), XY(3, 5), XY(6, 3)]
		)

		var ai = AI.Plan()
		guard case let .attack(_, target) = sim.run(ai: &ai) else {
			Issue.record("aircraft did not take an available attack")
			return
		}
		#expect(target == 2.uid)
	}

	@Test func hiddenSupportDoesNotChangeHeuristicAction() {
		func make(_ includeSupport: Bool) -> TacticalSim {
			var units = [
				Unit(model: .f35, country: .ger),
				Unit(model: .militia, country: .usa),
			]
			var positions = [XY(3, 3), XY(5, 3)]
			if includeSupport {
				units.append(Unit(model: .patriot, country: .usa))
				positions.append(XY(6, 3))
			}
			var sim = Self.duelSim(units: units, at: positions, fullVision: false)
			sim.vision[0] = .empty
			sim.vision[0][XY(3, 3)] = true
			sim.vision[0][XY(5, 3)] = true
			return sim
		}

		let withoutHidden = make(false)
		let withHidden = make(true)
		var first = AI.Plan()
		var second = AI.Plan()
		let a = withoutHidden.run(ai: &first)
		let b = withHidden.run(ai: &second)
		#expect(a == b)
		#expect(a == .attack(0.uid, 1.uid))
	}

	@Test func reachableHostileSettlementIsCapturedByMovement() {
		let sim = Self.duelSim(
			size: 8,
			cities: [(XY(0, 0), .ger), (XY(3, 0), .usa)],
			units: [Unit(model: .regular, country: .ger)],
			at: [XY(2, 0)]
		)

		var ai = AI.Plan()
		#expect(sim.run(ai: &ai) == .move(0.uid, XY(3, 0)))
	}

	@Test func rangedMoverSeeksPostMoveFiringPosition() {
		let sim = Self.duelSim(
			cities: [(XY(0, 1), .ger), (XY(9, 1), .usa)],
			units: [
				Unit(model: .m270, country: .ger),
				Unit(model: .militia, country: .usa),
			],
			at: [XY(1, 1), XY(6, 1)]
		)
		let range = Int(sim.units[0].rng) * 2 + 1
		#expect(sim.position[0].stepDistance(to: sim.position[1]) > range)

		var ai = AI.Plan()
		guard case let .move(source, destination) = sim.run(ai: &ai) else {
			Issue.record("mobile artillery did not seek a firing position")
			return
		}
		#expect(source == 0.uid)
		#expect(destination.stepDistance(to: sim.position[1]) <= range)
	}

	@Test func reusedRosterSlotReceivesFreshAssignment() {
		var sim = Self.plannedSim()
		var ai = AI.Plan()
		_ = sim.run(ai: &ai)
		let uid = sim.units.firstMapAlive { i, u in u.country == .ger ? i.uid : nil }!
		ai.role[uid.index] = .retreat

		sim.vacate(uid)
		sim.units[uid].hp = 0
		_ = sim.run(ai: &ai) // observe the slot leaving the roster
		var replacement = Unit(model: .m1A2, country: .ger)
		replacement.reset()
		let replacementID = sim.spawn(replacement, at: XY(2, 2))
		#expect(replacementID == uid)
		_ = sim.run(ai: &ai)

		let rosterContainsReplacement = ai.roster.contains(uid)
		#expect(rosterContainsReplacement)
		#expect(ai.role[uid.index] != .retreat)
		#expect(ai.country == .ger)
	}

	@Test func survivalHeuristicTurnsRemainBounded() {
		var sim = TacticalSim(
			players: [
				Player(country: .fin, type: .ai, prestige: .poor, tier: 3),
				Player(country: .isr, type: .ai, prestige: .poor, tier: 3),
			],
			units: .base(.fin),
			size: 32,
			seed: 1,
			objective: .survive(.axis, day: 40),
			forts: 1
		)
		var ai = AI.Plan()
		var actions = 0
		var turnActions = 0
		var observedTurn = sim.turn
		var maximum = 0
		while actions < 20_000, sim.winner == nil, sim.day <= 128 {
			if sim.turn != observedTurn {
				observedTurn = sim.turn
				turnActions = 0
			}
			let action = sim.run(ai: &ai)
			_ = sim.reduce(action)
			turnActions += 1
			maximum = max(maximum, turnActions)
			actions += 1
		}
		#expect(maximum <= 257)
		#expect(sim.winner != nil)
		#expect(actions < 20_000)
	}

	/// A generated map can hold more settlements than the plan's `CArray<64>`
	/// buckets — villages are emergent 3-way road junctions, so their count is
	/// unbounded. `preplan` must truncate instead of trapping (regression:
	/// RL collection crashed on a seed-2000 map).
	@Test func preplanHandlesSettlementOverflow() {
		var sim = Self.makeSim(seed: 1)

		// Paint 160 extra cities, alternating own / enemy control, so both
		// plan buckets overflow their 64-slot capacity.
		var painted = 0
		for xy in sim.map.indices where sim.map[xy] == .field {
			sim.map[xy] = .city
			sim.control[xy] = painted % 2 == 0 ? .ger : .usa
			painted += 1
			if painted == 160 { break }
		}
		sim.indexSettlements()
		#expect(painted == 160)

		var ai = AI.Plan()
		for _ in 0 ..< 5 {
			_ = sim.reduce(sim.run(ai: &ai))
		}
		#expect(ai.ownSettlements.count == 64)
		#expect(ai.enemySettlements.count == 64)
	}
}
