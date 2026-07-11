import Foundation
import COR
import Metal
import MetalPerformanceShadersGraph

/// `Train bc` — behavior-clones the heuristic AI from a replay corpus. Truncated BPTT
/// over `Batcher` windows on the `Net` graph, masked cross-entropy per head
/// weighted by applicability (target only where the kind takes a target, …),
/// autodiff + Adam with global-norm gradient clipping, PGW1 checkpoints.
enum BCTrainer {

	static func run(_ args: [String]) throws {
		var data = "tmp/runs/replays"
		var out = "tmp/runs/bc"
		var steps = 600
		var b = 16
		var t = 16
		var lr: Float = 3e-4
		var holdout = 8
		var ckpt = 200
		var wseed = 13
		var resume: String?

		try Args(args).parse { flag, next in
			switch flag {
			case "--data": data = try next()
			case "--out": out = try next()
			case "--steps": steps = try Int(next()) ?? steps
			case "--b": b = try Int(next()) ?? b
			case "--t": t = try Int(next()) ?? t
			case "--lr": lr = try Float(next()) ?? lr
			case "--holdout": holdout = try Int(next()) ?? holdout
			case "--ckpt": ckpt = try Int(next()) ?? ckpt
			case "--wseed": wseed = try Int(next()) ?? wseed
			case "--resume": resume = try next()
			default: throw TrainError.usage("unknown option \(flag)")
			}
		}

		let outDir = URL(fileURLWithPath: out, isDirectory: true)
		try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

		let files = try FileManager.default
			.contentsOfDirectory(at: URL(fileURLWithPath: data, isDirectory: true), includingPropertiesForKeys: nil)
			.filter { $0.pathExtension == "pgr" }
			.sorted { $0.lastPathComponent < $1.lastPathComponent }
		guard files.count >= 2 else { throw TrainError.usage("need a replay corpus (Train rollout) in \(data)") }

		// Every `holdout`-th battle is never trained on.
		let evalFiles = files.enumerated().filter { $0.offset % holdout == holdout - 1 }.map(\.element)
		let trainFiles = files.enumerated().filter { $0.offset % holdout != holdout - 1 }.map(\.element)
		print("corpus: \(trainFiles.count) train / \(evalFiles.count) held-out battles")

		let weights: LSTMWeights
		if let resume {
			weights = try LSTMWeights.load(resume)
		} else {
			weights = .random(seed: UInt64(wseed))
		}

		let graph = try BCGraph(weights: weights, b: b, t: t)
		let trainBatcher = Batcher(files: trainFiles, b: b, t: t, seed: 42)
		let evalBatcher = Batcher(files: evalFiles, b: b, t: t, seed: 43)

		var csv = "step,lr,loss,kind_ce,kind_acc,actor_ce,actor_acc,target_ce,target_acc,slot_ce,slot_acc\n"
		let clock = ContinuousClock()
		let start = clock.now

		func evaluate(_ windows: Int = 8) -> BCGraph.Metrics {
			var sum = BCGraph.Metrics()
			for _ in 0 ..< windows {
				let m = graph.step(evalBatcher.window(), lr: 0, update: false)
				evalBatcher.carry(h: m.h, c: m.c)
				sum.add(m, 1 / Float(windows))
			}
			return sum
		}

		for step in 1 ... steps {
			// Linear warmup into cosine decay to lr/10; Adam bias correction
			// folded into the fed rate.
			var rate = lr * min(1, Float(step) / 50)
			let progress = Float(step) / Float(steps)
			rate *= 0.55 + 0.45 * cosf(.pi * progress)
			let corrected = rate * (1 - powf(0.999, Float(step))).squareRoot() / (1 - powf(0.9, Float(step)))

			let m = graph.step(trainBatcher.window(), lr: corrected, update: true)
			trainBatcher.carry(h: m.h, c: m.c)

			csv += "\(step),\(rate),\(m.loss),\(m.kindCE),\(m.kindAcc),\(m.actorCE),\(m.actorAcc),\(m.targetCE),\(m.targetAcc),\(m.slotCE),\(m.slotAcc)\n"
			if step % 10 == 0 || step == 1 {
				print("step \(step)  loss \(f(m.loss))  kind \(f(m.kindAcc))  actor \(f(m.actorAcc))  target \(f(m.targetAcc))  slot \(f(m.slotAcc))  lr \(rate)")
			}
			if step % ckpt == 0 || step == steps {
				let e = evaluate()
				print("  eval  loss \(f(e.loss))  kind \(f(e.kindAcc))  actor \(f(e.actorAcc))  target \(f(e.targetAcc))  slot \(f(e.slotAcc))")
				try graph.checkpoint().data().write(to: outDir.appendingPathComponent("ckpt-\(step).pgw"))
				try csv.write(to: outDir.appendingPathComponent("bc-log.csv"), atomically: true, encoding: .utf8)
			}
		}

		try graph.checkpoint().data().write(to: outDir.appendingPathComponent("policy.pgw"))
		try csv.write(to: outDir.appendingPathComponent("bc-log.csv"), atomically: true, encoding: .utf8)
		let d = start.duration(to: clock.now).components
		print("── bc ──")
		print("  steps:    \(steps) (\(d.seconds)s)")
		print("  out:      \(outDir.path)/policy.pgw")
	}
}

/// The unrolled training graph: `Net.encode` over all B·T observations at
/// once (the trunk is step-independent), the LSTM cell looped over T slices,
/// heads over the stacked hidden states with teacher-forced actor
/// conditioning.
final class BCGraph {
	let graph = MPSGraph()
	let device: MPSGraphDevice
	let queue: MTLCommandQueue
	let b: Int
	let t: Int
	var n: Int { b * t }

	private let planes, globals, h0, c0, lrIn: MPSGraphTensor
	private let kindLabel, actorLabel, targetLabel, slotLabel: MPSGraphTensor
	private let kindW, actorW, targetW, slotW: MPSGraphTensor
	private let kindMask, actorMask, targetMask, slotMask: MPSGraphTensor
	private let loss, hT, cT: MPSGraphTensor
	private let ces: [MPSGraphTensor], accs: [MPSGraphTensor]
	private let updates: [MPSGraphOperation]
	private let vars: [String: MPSGraphTensor]

	struct Metrics {
		var loss: Float = 0
		var kindCE: Float = 0, kindAcc: Float = 0
		var actorCE: Float = 0, actorAcc: Float = 0
		var targetCE: Float = 0, targetAcc: Float = 0
		var slotCE: Float = 0, slotAcc: Float = 0
		var h: [Float] = [], c: [Float] = []

		mutating func add(_ m: Metrics, _ w: Float) {
			loss += m.loss * w
			kindCE += m.kindCE * w
			kindAcc += m.kindAcc * w
			actorCE += m.actorCE * w
			actorAcc += m.actorAcc * w
			targetCE += m.targetCE * w
			targetAcc += m.targetAcc * w
			slotCE += m.slotCE * w
			slotAcc += m.slotAcc * w
		}
	}

	init(weights: LSTMWeights, b: Int, t: Int) throws {
		guard let mtl = MTLCreateSystemDefaultDevice(), let q = mtl.makeCommandQueue() else {
			throw TrainError.failed("no Metal device")
		}
		device = MPSGraphDevice(mtlDevice: mtl)
		queue = q
		self.b = b
		self.t = t
		let n = b * t

		let g = graph
		let H = LSTMWeights.hidden
		let side = NSNumber(value: SimObservation.side)
		func ph(_ shape: [NSNumber], _ type: MPSDataType, _ name: String) -> MPSGraphTensor {
			g.placeholder(shape: shape, dataType: type, name: name)
		}
		planes = ph([NSNumber(value: n), side, side, NSNumber(value: SimObservation.planeCount)], .float32, "planes")
		globals = ph([NSNumber(value: n), NSNumber(value: SimObservation.globalCount)], .float32, "globals")
		h0 = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "h0")
		c0 = ph([NSNumber(value: b), NSNumber(value: H)], .float32, "c0")
		lrIn = ph([1], .float32, "lr")
		kindLabel = ph([NSNumber(value: n)], .int32, "kindLabel")
		actorLabel = ph([NSNumber(value: n)], .int32, "actorLabel")
		targetLabel = ph([NSNumber(value: n)], .int32, "targetLabel")
		slotLabel = ph([NSNumber(value: n)], .int32, "slotLabel")
		kindW = ph([NSNumber(value: n), 1], .float32, "kindW")
		actorW = ph([NSNumber(value: n), 1], .float32, "actorW")
		targetW = ph([NSNumber(value: n), 1], .float32, "targetW")
		slotW = ph([NSNumber(value: n), 1], .float32, "slotW")
		kindMask = ph([NSNumber(value: n), NSNumber(value: ActionSpace.kinds)], .float32, "kindMask")
		actorMask = ph([NSNumber(value: n), NSNumber(value: ActionSpace.tiles)], .float32, "actorMask")
		targetMask = ph([NSNumber(value: n), NSNumber(value: ActionSpace.tiles)], .float32, "targetMask")
		slotMask = ph([NSNumber(value: n), NSNumber(value: ActionSpace.slots)], .float32, "slotMask")

		let v = Net.variables(g, weights)
		vars = v
		let (trunk, x) = Net.encode(g, v, planes: planes, globals: globals, n: n)

		// Unroll: x [n, H] is t-major, so slice t rows of [b, H] at a time.
		let x3 = g.reshape(x, shape: [NSNumber(value: t), NSNumber(value: b), NSNumber(value: H)], name: nil)
		var h = h0
		var c = c0
		var hs = [MPSGraphTensor]()
		for step in 0 ..< t {
			let xt = g.reshape(
				g.sliceTensor(x3, dimension: 0, start: step, length: 1, name: nil),
				shape: [NSNumber(value: b), NSNumber(value: H)], name: nil
			)
			(h, c) = Net.cell(g, v, x: xt, h: h, c: c)
			hs.append(h)
		}
		hT = h
		cT = c
		let hAll = g.concatTensors(hs, dimension: 0, name: nil)		// [t·b, H], t-major

		let kindLogits = Net.kindHead(g, v, h: hAll)
		let actorLogits = Net.actorHead(g, v, trunk: trunk, h: hAll, n: n)
		let (targetLogits, slotLogits) = Net.condHeads(g, v, trunk: trunk, h: hAll, actor: actorLabel, n: n)

		func head(
			_ logits: MPSGraphTensor, _ mask: MPSGraphTensor, _ label: MPSGraphTensor,
			_ weight: MPSGraphTensor, _ k: Int
		) -> (ce: MPSGraphTensor, acc: MPSGraphTensor) {
			let one = g.constant(1, dataType: .float32)
			let masked = g.addition(
				logits,
				g.multiplication(
					g.subtraction(mask, one, name: nil),
					g.constant(1e9, dataType: .float32), name: nil
				), name: nil
			)
			let labels = g.oneHot(withIndicesTensor: label, depth: k, axis: 1, dataType: .float32, name: nil)
			let ce = g.reshape(
				g.softMaxCrossEntropy(masked, labels: labels, axis: 1, reuctionType: .none, name: nil),
				shape: [NSNumber(value: n), 1], name: nil
			)
			// Normalize by Σ|w| (not Σw): BC weights are 0/1 so nothing
			// changes, but the RL trainer feeds signed advantages as weights —
			// the CE numerator must stay signed (that IS the policy gradient)
			// while the divisor and the accuracy weighting must not cancel.
			let absW = g.absolute(with: weight, name: nil)
			let sumW = g.maximum(g.reductionSum(with: absW, axes: nil, name: nil), one, name: nil)
			let meanCE = g.division(g.reductionSum(with: g.multiplication(ce, weight, name: nil), axes: nil, name: nil), sumW, name: nil)

			let best = g.reductionArgMaximum(with: masked, axis: 1, name: nil)
			let correct = g.cast(
				g.equal(best, g.cast(g.reshape(label, shape: [NSNumber(value: n), 1], name: nil), to: best.dataType, name: nil), name: nil),
				to: .float32, name: nil
			)
			let acc = g.division(g.reductionSum(with: g.multiplication(correct, absW, name: nil), axes: nil, name: nil), sumW, name: nil)
			return (meanCE, acc)
		}

		let kind = head(kindLogits, kindMask, kindLabel, kindW, ActionSpace.kinds)
		let actor = head(actorLogits, actorMask, actorLabel, actorW, ActionSpace.tiles)
		let target = head(targetLogits, targetMask, targetLabel, targetW, ActionSpace.tiles)
		let slot = head(slotLogits, slotMask, slotLabel, slotW, ActionSpace.slots)
		ces = [kind.ce, actor.ce, target.ce, slot.ce]
		accs = [kind.acc, actor.acc, target.acc, slot.acc]
		loss = g.addition(g.addition(kind.ce, actor.ce, name: nil), g.addition(target.ce, slot.ce, name: nil), name: nil)

		// Global-norm gradient clip at 1.0, Adam on every reached variable.
		// The value head feeds no BC loss term and must stay out of the
		// gradient request (autodiff asserts on non-predecessors); it keeps
		// its initialization until the RL phase.
		let trainable = v.filter { !$0.key.hasPrefix("value.") }
		let grads = g.gradients(of: loss, with: Array(trainable.values), name: nil)
		var sumSq = g.constant(0, dataType: .float32)
		for grad in grads.values {
			sumSq = g.addition(sumSq, g.reductionSum(with: g.square(with: grad, name: nil), axes: nil, name: nil), name: nil)
		}
		let norm = g.squareRoot(with: sumSq, name: nil)
		let scale = g.minimum(
			g.constant(1, dataType: .float32),
			g.division(g.constant(1, dataType: .float32), g.addition(norm, g.constant(1e-12, dataType: .float32), name: nil), name: nil),
			name: nil
		)

		let beta1 = g.constant(0.9, dataType: .float32)
		let beta2 = g.constant(0.999, dataType: .float32)
		let epsilon = g.constant(1e-8, dataType: .float32)
		var ops = [MPSGraphOperation]()
		for (name, variable) in trainable {
			guard let grad = grads[variable] else { continue }
			let clipped = g.multiplication(grad, scale, name: nil)
			let shape = variable.shape!
			let zeros = floatData([Float](repeating: 0, count: shape.reduce(1) { $0 * $1.intValue }))
			let m = g.variable(with: zeros, shape: shape, dataType: .float32, name: "adam.m.\(name)")
			let vel = g.variable(with: zeros, shape: shape, dataType: .float32, name: "adam.v.\(name)")
			let adam = g.adam(
				currentLearningRate: lrIn, beta1: beta1, beta2: beta2, epsilon: epsilon,
				values: variable, momentum: m, velocity: vel, maximumVelocity: nil,
				gradient: clipped, name: nil
			)
			ops.append(g.assign(variable, tensor: adam[0], name: nil))
			ops.append(g.assign(m, tensor: adam[1], name: nil))
			ops.append(g.assign(vel, tensor: adam[2], name: nil))
		}
		updates = ops
	}

	/// One window through the graph; `update` runs the Adam assigns.
	/// The body drains its autorelease pool: feeds and results are
	/// autoreleased ObjC objects (~50 MB of planes per window), and a CLI
	/// has no runloop to drain them — long runs died of memory otherwise.
	func step(_ w: Batcher.Window, lr: Float, update: Bool) -> Metrics {
		autoreleasepool { stepBody(w, lr: lr, update: update) }
	}

	private func stepBody(_ w: Batcher.Window, lr: Float, update: Bool) -> Metrics {
		let side = NSNumber(value: SimObservation.side)
		let nn = NSNumber(value: n)
		let feeds: [MPSGraphTensor: MPSGraphTensorData] = [
			planes: tensorData(device, w.planes, [nn, side, side, NSNumber(value: SimObservation.planeCount)]),
			globals: tensorData(device, w.globals, [nn, NSNumber(value: SimObservation.globalCount)]),
			h0: tensorData(device, w.h0, [NSNumber(value: b), NSNumber(value: LSTMWeights.hidden)]),
			c0: tensorData(device, w.c0, [NSNumber(value: b), NSNumber(value: LSTMWeights.hidden)]),
			lrIn: tensorData(device, [lr], [1]),
			kindLabel: tensorData(device, w.kind, [nn]),
			actorLabel: tensorData(device, w.actor, [nn]),
			targetLabel: tensorData(device, w.target, [nn]),
			slotLabel: tensorData(device, w.slot, [nn]),
			kindW: tensorData(device, w.kindW, [nn, 1]),
			actorW: tensorData(device, w.actorW, [nn, 1]),
			targetW: tensorData(device, w.targetW, [nn, 1]),
			slotW: tensorData(device, w.slotW, [nn, 1]),
			kindMask: tensorData(device, w.kindMask, [nn, NSNumber(value: ActionSpace.kinds)]),
			actorMask: tensorData(device, w.actorMask, [nn, NSNumber(value: ActionSpace.tiles)]),
			targetMask: tensorData(device, w.targetMask, [nn, NSNumber(value: ActionSpace.tiles)]),
			slotMask: tensorData(device, w.slotMask, [nn, NSNumber(value: ActionSpace.slots)]),
		]
		let targets = [loss] + ces + accs + [hT, cT]
		let out = graph.run(with: queue, feeds: feeds, targetTensors: targets, targetOperations: update ? updates : nil)

		var metrics = Metrics()
		metrics.loss = readFloats(out[loss]!, 1)[0]
		metrics.kindCE = readFloats(out[ces[0]]!, 1)[0]
		metrics.actorCE = readFloats(out[ces[1]]!, 1)[0]
		metrics.targetCE = readFloats(out[ces[2]]!, 1)[0]
		metrics.slotCE = readFloats(out[ces[3]]!, 1)[0]
		metrics.kindAcc = readFloats(out[accs[0]]!, 1)[0]
		metrics.actorAcc = readFloats(out[accs[1]]!, 1)[0]
		metrics.targetAcc = readFloats(out[accs[2]]!, 1)[0]
		metrics.slotAcc = readFloats(out[accs[3]]!, 1)[0]
		metrics.h = readFloats(out[hT]!, b * LSTMWeights.hidden)
		metrics.c = readFloats(out[cT]!, b * LSTMWeights.hidden)
		return metrics
	}

	/// Current variable values as a PGW1-writable weight set.
	func checkpoint() -> LSTMWeights {
		autoreleasepool {
			let out = graph.run(with: queue, feeds: [:], targetTensors: Array(vars.values), targetOperations: nil)
			var values = [String: [Float]]()
			for (name, shape) in LSTMWeights.spec {
				values[name] = readFloats(out[vars[name]!]!, shape.reduce(1, *))
			}
			return LSTMWeights(values: values)
		}
	}
}
