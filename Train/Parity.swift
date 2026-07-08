import Foundation

/// `Train parity` — proves the MPSGraph `Model` and the pure-Swift
/// `LSTMPolicy` compute the same function. Plays battles with the Swift
/// policy (random weights) vs the heuristic; at every policy step the graph
/// runs on the identical inputs — same observation and the *Swift-carried*
/// h/c, so each comparison is one step given equal state, not an
/// accumulating drift measurement — and every head the policy actually
/// evaluated is compared, plus the next h/c and the value.
///
/// Gate: max |Δ| < 1e-3 on every compared tensor, and no masked-argmax flip
/// on any head where the Swift logit gap exceeds the same threshold (flips
/// inside the float-noise band are not disagreements).
enum Parity {

	static func run(_ args: [String]) throws {
		var steps = 1000
		var seed = 0
		var wseed = 13
		let threshold: Float = 1e-3

		try Args(args).parse { flag, next in
			switch flag {
			case "--steps": steps = try Int(next()) ?? steps
			case "--seed": seed = try Int(next()) ?? seed
			case "--wseed": wseed = try Int(next()) ?? wseed
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		let weights = LSTMWeights.random(seed: UInt64(wseed))
		var policy = LSTMPolicy(weights: weights)
		let model = try Model(weights: weights)

		var maxDiff = [String: Float]()
		var flips = 0
		var compared = 0
		var battle = seed

		func diff(_ head: String, _ a: [Float], _ b: [Float]) {
			var m: Float = 0
			for i in a.indices { m = max(m, abs(a[i] - b[i])) }
			maxDiff[head] = max(maxDiff[head] ?? 0, m)
		}

		/// A cross-implementation argmax flip only counts when the Swift-side
		/// logits weren't in a near-tie.
		func checkArgmax(_ head: String, _ swift: [Float], _ graph: [Float], _ mask: [Bool]) {
			guard
				let a = LSTMPolicy.argmax(swift, mask),
				let b = LSTMPolicy.argmax(graph, mask),
				a != b, abs(swift[a] - swift[b]) > threshold
			else { return }
			flips += 1
			print("  argmax flip on \(head): swift \(a) (\(swift[a])) vs graph \(b) (\(graph[b]))")
		}

		while compared < steps {
			var sim = Rollouts.replay(index: battle).makeSim()
			battle += 1
			policy.reset()
			var ai = TacticalSim.AI()

			while compared < steps, sim.aliveTeams.nonzeroBitCount > 1, sim.day <= 32 {
				guard sim.playerIndex == 0 else {
					_ = sim.reduce(sim.run(ai: &ai))
					continue
				}

				let obs = sim.observation()
				let h0 = policy.h
				let c0 = policy.c
				let (action, trace) = policy.traced(for: sim)

				if let trace {
					let out = model.step(
						planes: obs.planes, globals: obs.globals,
						h: h0, c: c0, actor: max(0, trace.actorTile)
					)
					let masks = sim.actionMasks()

					diff("kind", trace.kind, out.kind)
					diff("h", policy.h, out.h)
					diff("c", policy.c, out.c)
					diff("value", [policy.lastValue], [out.value])
					checkArgmax("kind", trace.kind, out.kind, masks.kinds)

					let kind = LSTMPolicy.argmax(trace.kind, masks.kinds).flatMap(ActionSpace.Kind.init)
					if let actor = trace.actor, let kind {
						diff("actor", actor, out.actor)
						checkArgmax("actor", actor, out.actor, masks.actors[kind.rawValue])
					}
					if let target = trace.target, let kind {
						diff("target", target, out.target)
						checkArgmax("target", target, out.target, sim.targetMask(kind, actor: trace.actorTile))
					}
					if let slot = trace.slot {
						diff("slot", slot, out.slot)
						checkArgmax("slot", slot, out.slot, sim.slotMask(actor: trace.actorTile))
					}
					compared += 1
				}
				_ = sim.reduce(action)
			}
		}

		print("── parity ──")
		print("  steps:    \(compared) (\(battle - seed) battles, weights seed \(wseed))")
		for head in maxDiff.keys.sorted() {
			print("  max |Δ|:  \(head): \(maxDiff[head]!)")
		}
		print("  argmax flips beyond \(threshold): \(flips)")

		let worst = maxDiff.values.max() ?? 0
		guard worst < threshold, flips == 0 else {
			throw TrainError.failed("parity gate: max |Δ| \(worst), \(flips) argmax flips")
		}
		print("  PASS")
	}
}
