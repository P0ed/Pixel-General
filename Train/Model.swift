import Foundation
import Metal
import MetalPerformanceShadersGraph

/// Single-step, batch-1 wiring of `Net` — what `Train parity` runs against
/// the pure-Swift `LSTMPolicy`. Because the BC/RL training graphs are built
/// from the same `Net` functions, the parity gate anchors the trainer's
/// forward pass too.
///
/// The target/slot conditioning tile arrives as an `Int32` placeholder —
/// during training that is the teacher's actor tile, here it is whatever the
/// Swift policy chose.
final class Model {
	let graph = MPSGraph()
	let device: MPSGraphDevice
	let queue: MTLCommandQueue

	let planes, globals, hIn, cIn, actorTile: MPSGraphTensor
	let kindLogits, actorLogits, targetLogits, slotLogits, valueOut, hOut, cOut: MPSGraphTensor

	struct Step {
		var kind, actor, target, slot, h, c: [Float]
		var value: Float
	}

	init(weights: LSTMWeights) throws {
		guard let mtl = MTLCreateSystemDefaultDevice(), let q = mtl.makeCommandQueue() else {
			throw TrainError.failed("no Metal device")
		}
		device = MPSGraphDevice(mtlDevice: mtl)
		queue = q

		let g = graph
		let side = NSNumber(value: SimObservation.side)
		planes = g.placeholder(shape: [1, side, side, NSNumber(value: SimObservation.planeCount)], dataType: .float32, name: "planes")
		globals = g.placeholder(shape: [1, NSNumber(value: SimObservation.globalCount)], dataType: .float32, name: "globals")
		hIn = g.placeholder(shape: [1, NSNumber(value: LSTMWeights.hidden)], dataType: .float32, name: "h")
		cIn = g.placeholder(shape: [1, NSNumber(value: LSTMWeights.hidden)], dataType: .float32, name: "c")
		actorTile = g.placeholder(shape: [1], dataType: .int32, name: "actorTile")

		let v = Net.variables(g, weights)
		let (trunk, x) = Net.encode(g, v, planes: planes, globals: globals, n: 1)
		(hOut, cOut) = Net.cell(g, v, x: x, h: hIn, c: cIn)
		kindLogits = Net.kindHead(g, v, h: hOut)
		actorLogits = Net.actorHead(g, v, trunk: trunk, h: hOut, n: 1)
		(targetLogits, slotLogits) = Net.condHeads(g, v, trunk: trunk, h: hOut, actor: actorTile, n: 1)
		valueOut = Net.valueHead(g, v, h: hOut)
	}

	/// One recurrent step: same inputs as `LSTMPolicy.step` plus the
	/// conditioning actor tile; returns every head plus the next h/c.
	/// Pool-drained like `BCGraph.step` — see the note there.
	func step(planes p: [Float], globals gl: [Float], h: [Float], c: [Float], actor: Int) -> Step {
		autoreleasepool { stepBody(planes: p, globals: gl, h: h, c: c, actor: actor) }
	}

	private func stepBody(planes p: [Float], globals gl: [Float], h: [Float], c: [Float], actor: Int) -> Step {
		let side = NSNumber(value: SimObservation.side)
		let feeds: [MPSGraphTensor: MPSGraphTensorData] = [
			planes: tensorData(device, p, [1, side, side, NSNumber(value: SimObservation.planeCount)]),
			globals: tensorData(device, gl, [1, NSNumber(value: SimObservation.globalCount)]),
			hIn: tensorData(device, h, [1, NSNumber(value: LSTMWeights.hidden)]),
			cIn: tensorData(device, c, [1, NSNumber(value: LSTMWeights.hidden)]),
			actorTile: tensorData(device, [Int32(actor)], [1]),
		]
		let out = graph.run(
			with: queue,
			feeds: feeds,
			targetTensors: [kindLogits, actorLogits, targetLogits, slotLogits, valueOut, hOut, cOut],
			targetOperations: nil
		)
		return Step(
			kind: readFloats(out[kindLogits]!, ActionSpace.kinds),
			actor: readFloats(out[actorLogits]!, ActionSpace.tiles),
			target: readFloats(out[targetLogits]!, ActionSpace.tiles),
			slot: readFloats(out[slotLogits]!, ActionSpace.slots),
			h: readFloats(out[hOut]!, LSTMWeights.hidden),
			c: readFloats(out[cOut]!, LSTMWeights.hidden),
			value: readFloats(out[valueOut]!, 1)[0]
		)
	}
}
