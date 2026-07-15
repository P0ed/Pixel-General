import Foundation
import COR
import Metal
import MetalPerformanceShadersGraph

/// The one MPSGraph expression of the `LSTMWeights` network, shared by the
/// parity `Model` (N = 1) and the BC/RL training graphs (N = B·T) — so the
/// graph the trainer optimizes is the same code `Train parity` proves
/// equivalent to the pure-Swift `LSTMPolicy`.
///
/// Everything is batched over a leading `n`: observations `[n, 32, 32, 53]`,
/// hidden states `[batch, H]`, per-tile trunk `[n, 1024, C]`. The 1×1 head
/// convolutions run as (leading-dim broadcast) matmuls over the flattened
/// trunk — bit-identical math, simpler graph.
enum Net {

	/// Every `LSTMWeights.spec` tensor as a graph variable initialized from
	/// `weights` — the trainable set; read-only for inference graphs.
	static func variables(_ g: MPSGraph, _ weights: LSTMWeights) -> [String: MPSGraphTensor] {
		var vars = [String: MPSGraphTensor]()
		for (name, shape) in LSTMWeights.spec {
			vars[name] = g.variable(
				with: floatData(weights[name]),
				shape: shape.map { NSNumber(value: $0) },
				dataType: .float32,
				name: name
			)
		}
		return vars
	}

	/// The same catalog as `variables`, but as graph *constants* — a frozen
	/// reference network (the PPO KL anchor). Constants have no gradient
	/// plumbing, so autodiff never traverses into the reference branch.
	static func constants(_ g: MPSGraph, _ weights: LSTMWeights) -> [String: MPSGraphTensor] {
		var consts = [String: MPSGraphTensor]()
		for (name, shape) in LSTMWeights.spec {
			consts[name] = g.constant(
				floatData(weights[name]),
				shape: shape.map { NSNumber(value: $0) },
				dataType: .float32
			)
		}
		return consts
	}

	/// Host-side Adam bias correction. The β₁ = 0.9 / β₂ = 0.999 here must
	/// match the beta constants baked into every training graph's `adam` ops.
	static func correctedLR(_ lr: Float, step: Int) -> Float {
		lr * (1 - powf(0.999, Float(step))).squareRoot() / (1 - powf(0.9, Float(step)))
	}

	/// SimObservation encoder: dilated conv trunk + pyramid-pooled features.
	/// `planes [n, 32, 32, P]`, `globals [n, G]` →
	/// (`trunk [n, 1024, C]`, `x [n, H]` — the LSTM input).
	///
	/// Dilations 1, 2, 4, 8, 1 give a 33×33 receptive field (≈ the full map);
	/// the trailing dense layer smooths the d8 gridding artifacts for the
	/// per-tile heads. The LSTM input pools the trunk at two scales — full-grid
	/// mean ⊕ the four 16×16 quadrant means, order q00 q01 q10 q11
	/// ((yHalf, xHalf) row-major, channels inner) — and must match
	/// `LSTMPolicy.step` exactly (parity is the oracle).
	static func encode(
		_ g: MPSGraph, _ v: [String: MPSGraphTensor],
		planes: MPSGraphTensor, globals: MPSGraphTensor, n: Int
	) -> (trunk: MPSGraphTensor, x: MPSGraphTensor) {
		var t = planes
		for (name, d) in [("conv1", 1), ("conv2", 2), ("conv3", 4), ("conv4", 8), ("conv5", 1)] {
			let desc = MPSGraphConvolution2DOpDescriptor(
				strideInX: 1, strideInY: 1, dilationRateInX: d, dilationRateInY: d,
				groups: 1, paddingStyle: .TF_SAME, dataLayout: .NHWC, weightsLayout: .HWIO
			)!
			t = g.reLU(with: g.addition(
				g.convolution2D(t, weights: v["\(name).w"]!, descriptor: desc, name: nil),
				v["\(name).b"]!, name: nil
			), name: nil)
		}
		let C = NSNumber(value: LSTMWeights.trunk)
		let trunk = g.reshape(t, shape: [NSNumber(value: n), NSNumber(value: ActionSpace.tiles), C], name: nil)

		let pooled = g.reshape(
			g.mean(of: t, axes: [1, 2], name: nil),
			shape: [NSNumber(value: n), C], name: nil
		)
		let half = NSNumber(value: SimObservation.side / 2)
		let quads = g.reshape(
			g.mean(of: g.reshape(t, shape: [NSNumber(value: n), 2, half, 2, half, C], name: nil), axes: [2, 4], name: nil),
			shape: [NSNumber(value: n), NSNumber(value: 4 * LSTMWeights.trunk)], name: nil
		)
		let x = g.reLU(with: fc(g, v, g.concatTensors([pooled, quads, globals], dimension: 1, name: nil), "fc1"), name: nil)
		return (trunk, x)
	}

	/// One LSTM step (gate order i, f, g, o): `x/h/c [batch, H]` → new (h, c).
	static func cell(
		_ g: MPSGraph, _ v: [String: MPSGraphTensor],
		x: MPSGraphTensor, h: MPSGraphTensor, c: MPSGraphTensor
	) -> (h: MPSGraphTensor, c: MPSGraphTensor) {
		let z = g.addition(g.addition(
			g.matrixMultiplication(primary: x, secondary: v["lstm.wx"]!, name: nil),
			g.matrixMultiplication(primary: h, secondary: v["lstm.wh"]!, name: nil), name: nil
		), v["lstm.b"]!, name: nil)
		// Four slices, not `split` — split has no registered gradient.
		let H = LSTMWeights.hidden
		let gates = (0 ..< 4).map { i in
			g.sliceTensor(z, dimension: 1, start: i * H, length: H, name: nil)
		}
		let c1 = g.addition(
			g.multiplication(g.sigmoid(with: gates[1], name: nil), c, name: nil),
			g.multiplication(g.sigmoid(with: gates[0], name: nil), g.tanh(with: gates[2], name: nil), name: nil),
			name: nil
		)
		let h1 = g.multiplication(g.sigmoid(with: gates[3], name: nil), g.tanh(with: c1, name: nil), name: nil)
		return (h1, c1)
	}

	static func kindHead(_ g: MPSGraph, _ v: [String: MPSGraphTensor], h: MPSGraphTensor) -> MPSGraphTensor {
		fc(g, v, h, "kind")
	}

	/// Actor logits `[n, 1024]` from trunk + the hidden-state projection.
	static func actorHead(
		_ g: MPSGraph, _ v: [String: MPSGraphTensor],
		trunk: MPSGraphTensor, h: MPSGraphTensor, n: Int
	) -> MPSGraphTensor {
		tileHead(g, v, trunk: trunk, per: fc(g, v, h, "actor.proj"), prefix: "actor", n: n)
	}

	/// Target `[n, 1024]` and slot `[n, slots]` logits, conditioned on the
	/// actor tile (`actor [n] int32` — teacher-forced during training).
	static func condHeads(
		_ g: MPSGraph, _ v: [String: MPSGraphTensor],
		trunk: MPSGraphTensor, h: MPSGraphTensor, actor: MPSGraphTensor, n: Int
	) -> (target: MPSGraphTensor, slot: MPSGraphTensor) {
		let idx = g.reshape(actor, shape: [NSNumber(value: n), 1], name: nil)
		let actorTrunk = g.reshape(
			g.gather(withUpdatesTensor: trunk, indicesTensor: idx, axis: 1, batchDimensions: 1, name: nil),
			shape: [NSNumber(value: n), NSNumber(value: LSTMWeights.trunk)], name: nil
		)
		let cond = g.concatTensors([h, actorTrunk], dimension: 1, name: nil)
		let target = tileHead(
			g, v,
			trunk: trunk,
			per: g.reLU(with: fc(g, v, cond, "target.cond"), name: nil),
			prefix: "target", n: n
		)
		let slot = fc(g, v, g.reLU(with: fc(g, v, cond, "slot.fc1"), name: nil), "slot.fc2")
		return (target, slot)
	}

	static func valueHead(_ g: MPSGraph, _ v: [String: MPSGraphTensor], h: MPSGraphTensor) -> MPSGraphTensor {
		fc(g, v, g.reLU(with: fc(g, v, h, "value.fc1"), name: nil), "value.fc2")
	}

	// MARK: - Pieces

	/// `y = x @ W + b`.
	static func fc(_ g: MPSGraph, _ v: [String: MPSGraphTensor], _ x: MPSGraphTensor, _ name: String) -> MPSGraphTensor {
		g.addition(
			g.matrixMultiplication(primary: x, secondary: v["\(name).w"]!, name: nil),
			v["\(name).b"]!, name: nil
		)
	}

	/// Per-tile logits `[n, 1024]`: `[trunk ⊕ per]` → 1×1 → ReLU → 1×1.
	private static func tileHead(
		_ g: MPSGraph, _ vars: [String: MPSGraphTensor],
		trunk: MPSGraphTensor, per: MPSGraphTensor, prefix: String, n: Int
	) -> MPSGraphTensor {
		let tiles = NSNumber(value: ActionSpace.tiles)
		// Broadcast `per` across tiles via an implicit-broadcast addition —
		// the explicit `broadcast` op has no registered gradient.
		let perB = g.addition(
			g.reshape(per, shape: [NSNumber(value: n), 1, NSNumber(value: LSTMWeights.proj)], name: nil),
			g.constant(0, shape: [NSNumber(value: n), tiles, NSNumber(value: LSTMWeights.proj)], dataType: .float32),
			name: nil
		)
		let fusedT = g.concatTensors([trunk, perB], dimension: 2, name: nil)
		let w1 = g.reshape(vars["\(prefix).conv1.w"]!, shape: [NSNumber(value: LSTMWeights.fused), NSNumber(value: LSTMWeights.proj)], name: nil)
		let w2 = g.reshape(vars["\(prefix).conv2.w"]!, shape: [NSNumber(value: LSTMWeights.proj), 1], name: nil)
		let hid = g.reLU(with: g.addition(
			g.matrixMultiplication(primary: fusedT, secondary: w1, name: nil),
			vars["\(prefix).conv1.b"]!, name: nil
		), name: nil)
		let out = g.addition(
			g.matrixMultiplication(primary: hid, secondary: w2, name: nil),
			vars["\(prefix).conv2.b"]!, name: nil
		)
		return g.reshape(out, shape: [NSNumber(value: n), tiles], name: nil)
	}
}

// MARK: - Tensor data plumbing

func floatData(_ values: [Float]) -> Data {
	unsafe values.withUnsafeBufferPointer { unsafe Data(buffer: $0) }
}

func tensorData(_ device: MPSGraphDevice, _ values: [Float], _ shape: [NSNumber]) -> MPSGraphTensorData {
	MPSGraphTensorData(device: device, data: floatData(values), shape: shape, dataType: .float32)
}

func tensorData(_ device: MPSGraphDevice, _ values: [Int32], _ shape: [NSNumber]) -> MPSGraphTensorData {
	let data = unsafe values.withUnsafeBufferPointer { unsafe Data(buffer: $0) }
	return MPSGraphTensorData(device: device, data: data, shape: shape, dataType: .int32)
}

func readFloats(_ td: MPSGraphTensorData, _ count: Int) -> [Float] {
	var out = [Float](repeating: 0, count: count)
	unsafe out.withUnsafeMutableBufferPointer { buf in
		unsafe td.mpsndarray().readBytes(buf.baseAddress!, strideBytes: nil)
	}
	return out
}
