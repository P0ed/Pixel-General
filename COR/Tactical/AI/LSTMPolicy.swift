import Accelerate
import Foundation

/// Dependency-free (Accelerate-only) inference for the trained LSTM opponent.
/// One call per action, mirroring `run(ai:)`: encode the observation, run the
/// network, and pick the best *legal* action by hierarchical masked argmax —
/// kind, then actor tile, then target tile or shop slot. Deterministic and
/// RNG-free, so multiplayer and replay determinism are untouched; the masks
/// (`ActionSpace`) guarantee the result never no-ops through `reduce`.
///
/// The hidden state carries across the whole battle (that is the LSTM's
/// memory); create a fresh policy — or `reset()` — per battle.
public struct LSTMPolicy {
	public static let maxActionsPerTurn = 256

	let w: LSTMWeights
	public private(set) var h = [Float](repeating: 0, count: LSTMWeights.hidden)
	public private(set) var c = [Float](repeating: 0, count: LSTMWeights.hidden)
	var lastTurn = UInt32.max
	var actionsThisTurn = 0

	/// Critic's estimate of the last observation, for the RL trainer's logs.
	public private(set) var lastValue: Float = 0

	public init(weights: LSTMWeights) {
		w = weights
	}

	public mutating func reset() {
		self = LSTMPolicy(weights: w)
	}

	/// The policy's move for the acting player. Always legal; `.end` when the
	/// network says so, when nothing else is legal, or as a runaway-turn guard.
	public mutating func action(for sim: borrowing TacticalSim) -> TacticalAction {
		traced(for: sim).0
	}

	/// One forward pass's head outputs, for the parity harness (`Train parity`)
	/// to compare against the MPSGraph model. Heads the chosen kind never ran
	/// are `nil`.
	public struct Trace {
		public var kind: [Float]
		public var actor: [Float]?
		public var target: [Float]?
		public var slot: [Float]?
		public var actorTile = -1
	}

	/// `action(for:)` plus the trace; the trace is `nil` only on the
	/// runaway-turn guard, where no forward pass runs. `select` picks the
	/// index at every head — masked argmax for play, masked sampling in the
	/// RL trainer; whatever it returns must respect the mask.
	public mutating func traced(
		for sim: borrowing TacticalSim,
		select: ([Float], [Bool]) -> Int? = LSTMPolicy.argmax
	) -> (TacticalAction, Trace?) {
		if sim.turn != lastTurn {
			// A turn counter running backwards means a new battle is reusing
			// this policy — stale memory of another map must not leak in.
			if sim.turn < lastTurn { reset() }
			lastTurn = sim.turn
			actionsThisTurn = 0
		}
		actionsThisTurn += 1
		guard actionsThisTurn <= Self.maxActionsPerTurn else { return (.end, nil) }

		let trunk = step(sim.observation())
		let masks = sim.actionMasks()

		var trace = Trace(kind: fc(h, "kind"))
		guard
			let k = select(trace.kind, masks.kinds),
			let kind = ActionSpace.Kind(rawValue: k), kind != .end
		else { return (.end, trace) }

		let proj = fc(h, "actor.proj")
		trace.actor = tileHead(trunk, per: proj, prefix: "actor")
		guard let actor = select(trace.actor!, masks.actors[k]) else { return (.end, trace) }
		trace.actorTile = actor

		var idx = ActionIndices(kind: kind, actor: actor)
		let actorTrunk = Array(trunk[actor * LSTMWeights.trunk ..< (actor + 1) * LSTMWeights.trunk])

		switch kind {
		case .move, .embark, .disembark, .attack:
			let cond = relu(fc(h + actorTrunk, "target.cond"))
			trace.target = tileHead(trunk, per: cond, prefix: "target")
			guard let target = select(trace.target!, sim.targetMask(kind, actor: actor)) else { return (.end, trace) }
			idx.target = target
		case .purchase:
			trace.slot = fc(relu(fc(h + actorTrunk, "slot.fc1")), "slot.fc2")
			guard let slot = select(trace.slot!, sim.slotMask(actor: actor)) else { return (.end, trace) }
			idx.slot = slot
		case .resupply, .end:
			break
		}

		return (sim.action(idx) ?? .end, trace)
	}

	// MARK: - Forward pass

	/// Runs the recurrent trunk on one observation, updating `h`/`c` and
	/// `lastValue`; returns the per-tile trunk features `[1024, trunk]`.
	mutating func step(_ obs: SimObservation) -> [Float] {
		var t = relu(conv3x3(obs.planes, channels: SimObservation.planeCount, "conv1"))
		t = relu(conv3x3(t, channels: LSTMWeights.trunk, "conv2"))
		t = relu(conv3x3(t, channels: LSTMWeights.trunk, "conv3"))

		// Global mean pool over the full 32×32 grid (off-map tiles are zero
		// everywhere, including after ReLU convs on zero input… only near the
		// map edge do they carry signal — which is fine, it is the same grid
		// the trainer pools over).
		var pooled = [Float](repeating: 0, count: LSTMWeights.trunk)
		for tile in 0 ..< SimObservation.planeSize {
			for ch in 0 ..< LSTMWeights.trunk {
				pooled[ch] += t[tile * LSTMWeights.trunk + ch]
			}
		}
		for ch in pooled.indices { pooled[ch] /= Float(SimObservation.planeSize) }

		let x = relu(fc(pooled + obs.globals, "fc1"))

		// LSTM cell, gate order i, f, g, o.
		let H = LSTMWeights.hidden
		var z = mmul(x, w["lstm.wx"], m: 1, p: H, n: 4 * H)
		let zh = mmul(h, w["lstm.wh"], m: 1, p: H, n: 4 * H)
		let b = w["lstm.b"]
		for i in z.indices { z[i] += zh[i] + b[i] }
		for i in 0 ..< H {
			let ig = sigmoid(z[i])
			let fg = sigmoid(z[H + i])
			let gg = tanhf(z[2 * H + i])
			let og = sigmoid(z[3 * H + i])
			c[i] = fg * c[i] + ig * gg
			h[i] = og * tanhf(c[i])
		}

		lastValue = fc(relu(fc(h, "value.fc1")), "value.fc2")[0]
		return t
	}

	/// Per-tile logits: `[trunk ⊕ per]` → 1×1 conv → ReLU → 1×1 conv → `[1024]`.
	func tileHead(_ trunk: [Float], per: [Float], prefix: String) -> [Float] {
		let n = SimObservation.planeSize
		var fused = [Float](repeating: 0, count: n * LSTMWeights.fused)
		for tile in 0 ..< n {
			let o = tile * LSTMWeights.fused
			for ch in 0 ..< LSTMWeights.trunk {
				fused[o + ch] = trunk[tile * LSTMWeights.trunk + ch]
			}
			for ch in 0 ..< LSTMWeights.proj {
				fused[o + LSTMWeights.trunk + ch] = per[ch]
			}
		}
		var t = mmul(fused, w["\(prefix).conv1.w"], m: n, p: LSTMWeights.fused, n: LSTMWeights.proj)
		addBias(&t, w["\(prefix).conv1.b"])
		t = relu(t)
		t = mmul(t, w["\(prefix).conv2.w"], m: n, p: LSTMWeights.proj, n: 1)
		addBias(&t, w["\(prefix).conv2.b"])
		return t
	}

	/// Same-padded 3×3 convolution over the 32×32 HWC grid: im2col into
	/// `[1024, 9·channels]`, one matmul against the HWIO kernel.
	func conv3x3(_ input: [Float], channels: Int, _ name: String) -> [Float] {
		let side = SimObservation.side
		let patch = 9 * channels
		var cols = [Float](repeating: 0, count: side * side * patch)

		for y in 0 ..< side {
			for x in 0 ..< side {
				let row = (y * side + x) * patch
				for ky in 0 ..< 3 {
					let sy = y + ky - 1
					guard sy >= 0, sy < side else { continue }
					for kx in 0 ..< 3 {
						let sx = x + kx - 1
						guard sx >= 0, sx < side else { continue }
						let src = (sy * side + sx) * channels
						let dst = row + (ky * 3 + kx) * channels
						for ch in 0 ..< channels {
							cols[dst + ch] = input[src + ch]
						}
					}
				}
			}
		}

		let out = LSTMWeights.trunk
		var t = mmul(cols, w["\(name).w"], m: side * side, p: patch, n: out)
		addBias(&t, w["\(name).b"])
		return t
	}

	/// `y = x @ W + b` for a single row; `name` resolves `name.w`/`name.b`.
	func fc(_ x: [Float], _ name: String) -> [Float] {
		let wm = w["\(name).w"]
		let n = wm.count / x.count
		var y = mmul(x, wm, m: 1, p: x.count, n: n)
		addBias(&y, w["\(name).b"])
		return y
	}

	// MARK: - Primitives

	func mmul(_ a: [Float], _ b: [Float], m: Int, p: Int, n: Int) -> [Float] {
		var c = [Float](repeating: 0, count: m * n)
		unsafe a.withUnsafeBufferPointer { pa in
			unsafe b.withUnsafeBufferPointer { pb in
				unsafe c.withUnsafeMutableBufferPointer { pc in
					unsafe vDSP_mmul(
						pa.baseAddress!, 1, pb.baseAddress!, 1, pc.baseAddress!, 1,
						vDSP_Length(m), vDSP_Length(n), vDSP_Length(p)
					)
				}
			}
		}
		return c
	}

	func addBias(_ t: inout [Float], _ b: [Float]) {
		let n = b.count
		for i in t.indices { t[i] += b[i % n] }
	}

	func relu(_ t: [Float]) -> [Float] {
		t.map { v in max(0, v) }
	}

	func sigmoid(_ v: Float) -> Float {
		1 / (1 + expf(-v))
	}

	/// Index of the maximum logit among set mask bits; `nil` if none is set.
	public static func argmax(_ logits: [Float], _ mask: [Bool]) -> Int? {
		var best: Int?
		for i in logits.indices where mask[i] {
			if let b = best, logits[b] >= logits[i] { continue }
			best = i
		}
		return best
	}
}
