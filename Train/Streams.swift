import Foundation

/// One BC example: the observation the teacher saw, the factored labels of
/// the action it chose, and the legality masks at that state (the same masks
/// inference applies, so training and play optimize the identical
/// distribution). Labels are `-1` where the kind has no such head.
struct Sample {
	var planes: [Float]
	var globals: [Float]
	var kind: Int32
	var actor: Int32 = -1
	var target: Int32 = -1
	var slot: Int32 = -1
	var kindMask: [Float]
	var actorMask = [Float](repeating: 0, count: ActionSpace.tiles)
	var targetMask = [Float](repeating: 0, count: ActionSpace.tiles)
	var slotMask = [Float](repeating: 0, count: ActionSpace.slots)
}

/// Replays one battle through `reduce` and yields one seat's samples in
/// order — the teacher (axisAI) drove both seats, so every action of the
/// seat is a label, observed under that seat's fog.
final class SampleStream {
	private var state: TacticalState
	private let actions: [TacticalAction]
	private let seat: Int
	private var cursor = 0

	init(replay: Replay, seat: Int) {
		state = replay.makeState()
		actions = replay.actions
		self.seat = seat
	}

	func next() -> Sample? {
		while cursor < actions.count {
			let action = actions[cursor]
			cursor += 1
			var sample: Sample?
			if state.sim.playerIndex == seat, let idx = state.sim.actionIndices(action) {
				sample = Self.sample(state.sim, idx)
			}
			_ = state.reduce(action)
			if let sample { return sample }
		}
		return nil
	}

	private static func sample(_ sim: borrowing TacticalSim, _ idx: ActionIndices) -> Sample {
		let obs = sim.observation()
		let masks = sim.actionMasks()
		var s = Sample(
			planes: obs.planes,
			globals: obs.globals,
			kind: Int32(idx.kind.rawValue),
			kindMask: masks.kinds.map { $0 ? 1 : 0 }
		)
		guard idx.kind != .end else { return s }

		s.actor = Int32(idx.actor)
		s.actorMask = masks.actors[idx.kind.rawValue].map { $0 ? 1 : 0 }
		switch idx.kind {
		case .move, .embark, .disembark, .attack:
			s.target = Int32(idx.target)
			s.targetMask = sim.targetMask(idx.kind, actor: idx.actor).map { $0 ? 1 : 0 }
		case .purchase:
			s.slot = Int32(idx.slot)
			s.slotMask = sim.slotMask(actor: idx.actor).map { $0 ? 1 : 0 }
		case .resupply, .end:
			break
		}
		return s
	}
}

/// Truncated-BPTT batcher: `b` parallel stream lanes × `t` steps per window,
/// t-major layout (`n = step * b + lane`). Hidden state is carried across
/// windows per lane by the trainer (`carry`); when a stream ends mid-window
/// the rest of the lane's window is zero-weight padding and the lane restarts
/// with a fresh stream — and zeroed h/c — at the next window boundary.
final class Batcher {
	let b: Int
	let t: Int
	var n: Int { b * t }

	private let files: [URL]
	private var rng: UInt64
	private var order: [Int] = []
	private var cursor = 0
	private var lanes: [Lane]

	private struct Lane {
		var stream: SampleStream?
		var h = [Float](repeating: 0, count: LSTMWeights.hidden)
		var c = [Float](repeating: 0, count: LSTMWeights.hidden)
	}

	struct Window {
		var planes, globals: [Float]
		var kind, actor, target, slot: [Int32]
		var kindW, actorW, targetW, slotW: [Float]
		var kindMask, actorMask, targetMask, slotMask: [Float]
		var h0, c0: [Float]
		var samples = 0
	}

	init(files: [URL], b: Int, t: Int, seed: UInt64) {
		self.files = files
		self.b = b
		self.t = t
		rng = seed
		lanes = [Lane](repeating: Lane(), count: b)
	}

	/// Streams are battle-seat pairs, shuffled anew each epoch.
	private func nextStream() -> SampleStream? {
		if cursor >= order.count {
			order = Array(0 ..< files.count * 2)
			for i in (1 ..< order.count).reversed() {
				order.swapAt(i, Int(random() % UInt64(i + 1)))
			}
			cursor = 0
		}
		guard !order.isEmpty else { return nil }
		let id = order[cursor]
		cursor += 1
		guard let replay = try? Replay.read(files[id / 2]) else { return nil }
		return SampleStream(replay: replay, seat: id % 2)
	}

	func window() -> Window {
		let planeCount = Observation.planeSize * Observation.planeCount
		var w = Window(
			planes: [Float](repeating: 0, count: n * planeCount),
			globals: [Float](repeating: 0, count: n * Observation.globalCount),
			kind: [Int32](repeating: 0, count: n),
			actor: [Int32](repeating: 0, count: n),
			target: [Int32](repeating: 0, count: n),
			slot: [Int32](repeating: 0, count: n),
			kindW: [Float](repeating: 0, count: n),
			actorW: [Float](repeating: 0, count: n),
			targetW: [Float](repeating: 0, count: n),
			slotW: [Float](repeating: 0, count: n),
			kindMask: [Float](repeating: 0, count: n * ActionSpace.kinds),
			actorMask: [Float](repeating: 0, count: n * ActionSpace.tiles),
			targetMask: [Float](repeating: 0, count: n * ActionSpace.tiles),
			slotMask: [Float](repeating: 0, count: n * ActionSpace.slots),
			h0: [Float](repeating: 0, count: b * LSTMWeights.hidden),
			c0: [Float](repeating: 0, count: b * LSTMWeights.hidden)
		)

		for lane in 0 ..< b {
			if lanes[lane].stream == nil {
				lanes[lane].stream = nextStream()
				lanes[lane].h = [Float](repeating: 0, count: LSTMWeights.hidden)
				lanes[lane].c = [Float](repeating: 0, count: LSTMWeights.hidden)
			}
			for i in 0 ..< LSTMWeights.hidden {
				w.h0[lane * LSTMWeights.hidden + i] = lanes[lane].h[i]
				w.c0[lane * LSTMWeights.hidden + i] = lanes[lane].c[i]
			}

			for step in 0 ..< t {
				guard let s = lanes[lane].stream?.next() else {
					lanes[lane].stream = nil		// pad the rest; fresh stream next window
					break
				}
				let i = step * b + lane
				w.planes.replaceSubrange(i * planeCount ..< (i + 1) * planeCount, with: s.planes)
				w.globals.replaceSubrange(i * Observation.globalCount ..< (i + 1) * Observation.globalCount, with: s.globals)
				w.kindMask.replaceSubrange(i * ActionSpace.kinds ..< (i + 1) * ActionSpace.kinds, with: s.kindMask)
				w.actorMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.actorMask)
				w.targetMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.targetMask)
				w.slotMask.replaceSubrange(i * ActionSpace.slots ..< (i + 1) * ActionSpace.slots, with: s.slotMask)
				w.kind[i] = s.kind
				w.kindW[i] = 1
				if s.actor >= 0 {
					w.actor[i] = s.actor
					w.actorW[i] = 1
				}
				if s.target >= 0 {
					w.target[i] = s.target
					w.targetW[i] = 1
				}
				if s.slot >= 0 {
					w.slot[i] = s.slot
					w.slotW[i] = 1
				}
				w.samples += 1
			}
		}
		return w
	}

	/// Carries the window-final hidden state into each lane that still has a
	/// live stream (`h`/`c` are `[b * hidden]`, lane-major).
	func carry(h: [Float], c: [Float]) {
		for lane in 0 ..< b where lanes[lane].stream != nil {
			for i in 0 ..< LSTMWeights.hidden {
				lanes[lane].h[i] = h[lane * LSTMWeights.hidden + i]
				lanes[lane].c[i] = c[lane * LSTMWeights.hidden + i]
			}
		}
	}

	private func random() -> UInt64 {
		rng &+= 0x9E37_79B9_7F4A_7C15
		var z = rng
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		return z ^ (z >> 31)
	}
}
