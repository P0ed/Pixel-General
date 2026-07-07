import Testing
import Foundation
@testable import COR

/// Contracts of the LSTM policy plumbing (see Docs/LSTM-AI.md):
/// the observation encoding is fog-correct, and the factored action space
/// (`ActionSpace`) masks exactly the actions `reduce` accepts.
struct PolicyTests {

	private static func makeState(seed: Int, size: Int = 24) -> TacticalState {
		TacticalState(
			players: [
				Player(country: .ger, type: .ai, prestige: .rich, baseLevel: 0),
				Player(country: .usa, type: .ai, prestige: .rich, baseLevel: 0),
			],
			units: .base(.ger),
			size: size,
			seed: seed
		)
	}

	/// SplitMix64, deliberately separate from the sim's `D20`: sampling for
	/// tests must never advance combat randomness.
	private struct Rand {
		var s: UInt64
		mutating func next() -> UInt64 {
			s &+= 0x9E37_79B9_7F4A_7C15
			var z = s
			z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
			z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
			return z ^ (z >> 31)
		}
		mutating func pick(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
	}

	// MARK: - SimObservation

	@Test func observationRespectsFog() {
		var state = Self.makeState(seed: 3)
		var ai = TacticalSim.AI()

		// Play into the midgame so fog actually hides units.
		for _ in 0 ..< 300 {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }
			_ = state.reduce(state.sim.axis(ai: &ai))
		}

		let obs = state.sim.observation()
		let side = SimObservation.side
		let c = SimObservation.planeCount
		func plane(_ xy: XY, _ p: Int) -> Float { obs.planes[(xy.y * side + xy.x) * c + p] }

		let myTeam = state.sim.player.country.team
		var friendly = 0
		var enemies = 0

		for y in 0 ..< side {
			for x in 0 ..< side {
				let xy = XY(x, y)
				let onMap = plane(xy, Plane.onMap)
				#expect(onMap == (state.sim.map.contains(xy) ? 1 : 0))

				// Fog: an enemy in the tensor must be a visible one.
				if plane(xy, Plane.unitEnemy) == 1 {
					#expect(plane(xy, Plane.visible) == 1)
					#expect(state.sim.vision[state.sim.playerIndex][xy])
				}
				friendly += plane(xy, Plane.unitFriendly) == 1 ? 1 : 0
				enemies += plane(xy, Plane.unitEnemy) == 1 ? 1 : 0
			}
		}

		// Plane counts match a direct census of the sim.
		let expected = state.sim.units.reduceAlive(into: (0, 0)) { r, i, u in
			guard !state.sim.offMap(unit: i.uid) else { return }
			if u.country.team == myTeam {
				r.0 += 1
			} else if state.sim.vision[state.sim.playerIndex][state.sim.position[i]] {
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
		var state = Self.makeState(seed: 5)
		var ai = TacticalSim.AI()

		var steps = 0
		while steps < 600, state.sim.aliveTeams.nonzeroBitCount > 1, state.sim.day <= 16 {
			let action = state.sim.axis(ai: &ai)
			let idx = state.sim.actionIndices(action)
			guard let idx else {
				Issue.record("axisAI emitted an unencodable action: \(action)")
				break
			}

			#expect(state.sim.action(idx) == action, "round-trip failed for \(action)")

			if idx.kind != .end {
				let masks = state.sim.actionMasks()
				#expect(masks.kinds[idx.kind.rawValue], "kind \(idx.kind) masked off for \(action)")
				#expect(masks.actors[idx.kind.rawValue][idx.actor], "actor masked off for \(action)")

				switch idx.kind {
				case .move, .embark, .disembark, .attack:
					let targets = state.sim.targetMask(idx.kind, actor: idx.actor)
					#expect(targets[idx.target], "target masked off for \(action)")
				case .purchase:
					let slots = state.sim.slotMask(actor: idx.actor)
					#expect(idx.slot >= 0 && idx.slot < ActionSpace.slots && slots[idx.slot], "slot masked off for \(action)")
				case .resupply, .end:
					break
				}
			}

			_ = state.reduce(action)
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
		var state = Self.makeState(seed: 9)
		var policy = LSTMPolicy(weights: .random(seed: 13))
		var ai = TacticalSim.AI()

		var policySteps = 0
		var mutations = 0
		for _ in 0 ..< 400 {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }
			if policySteps >= 120 { break }

			if state.sim.playerIndex == 0 {
				let action = policy.action(for: state.sim)
				let before = encode(state.sim)
				_ = state.reduce(action)
				policySteps += 1
				if action != .end {
					#expect(encode(state.sim) != before, "policy action was a no-op: \(action)")
					mutations += 1
				}
				#expect(policy.lastValue.isFinite)
			} else {
				_ = state.reduce(state.sim.axis(ai: &ai))
			}
		}

		#expect(policySteps > 20, "battle stalled — policy never got to act")
		#expect(mutations > 0, "policy only ever ended its turn")
	}

	/// A maximally uninformed (random) but mask-respecting policy: every
	/// sampled non-`.end` action must mutate the encoded state — the reducers
	/// no-op on illegal input, so mutation is the legality oracle.
	@Test func maskedRandomActionsAlwaysMutateState() {
		var state = Self.makeState(seed: 7)
		var rand = Rand(s: 42)
		var perTurn = 0

		for _ in 0 ..< 400 {
			if state.sim.aliveTeams.nonzeroBitCount <= 1 { break }

			let masks = state.sim.actionMasks()
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
					let targets = state.sim.targetMask(kind, actor: actor)
					let legal = targets.indices.filter { targets[$0] }
					#expect(!legal.isEmpty, "actor masked legal but no target for \(kind)")
					guard !legal.isEmpty else { continue }
					idx.target = legal[rand.pick(legal.count)]
				case .purchase:
					let slots = state.sim.slotMask(actor: actor)
					let legal = slots.indices.filter { slots[$0] }
					#expect(!legal.isEmpty, "purchase masked legal but no affordable slot")
					guard !legal.isEmpty else { continue }
					idx.slot = legal[rand.pick(legal.count)]
				case .resupply, .end:
					break
				}
				guard let decoded = state.sim.action(idx) else {
					Issue.record("legal indices failed to decode: \(idx)")
					continue
				}
				action = decoded
			}

			let turnBefore = state.sim.turn
			let before = encode(state.sim)
			_ = state.reduce(action)

			if action != .end {
				#expect(encode(state.sim) != before, "masked action was a no-op: \(action)")
				perTurn += 1
			} else {
				perTurn = 0
				#expect(state.sim.turn != turnBefore || state.sim.aliveTeams.nonzeroBitCount <= 1)
			}
		}
	}

	// MARK: - Heuristic AI

	/// A generated map can hold more settlements than the plan's `CArray<64>`
	/// buckets — villages are emergent 3-way road junctions, so their count is
	/// unbounded. `preplan` must truncate instead of trapping (regression:
	/// RL collection crashed on a seed-2000 map).
	@Test func preplanHandlesSettlementOverflow() {
		var state = Self.makeState(seed: 1)

		// Paint 160 extra cities, alternating own / enemy control, so both
		// plan buckets overflow their 64-slot capacity.
		var painted = 0
		for xy in state.sim.map.indices where state.sim.map[xy] == .field {
			state.sim.map[xy] = .city
			state.sim.control[xy] = painted % 2 == 0 ? .ger : .usa
			painted += 1
			if painted == 160 { break }
		}
		#expect(painted == 160)

		var ai = TacticalSim.AI()
		for _ in 0 ..< 5 {
			_ = state.reduce(state.sim.axis(ai: &ai))
		}
		#expect(ai.ownSettlements.count == 64)
		#expect(ai.enemySettlements.count == 64)
	}
}
