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
	private var sim: TacticalSim
	private let actions: [TacticalAction]
	private let seat: Int
	private var cursor = 0

	init(replay: Replay, seat: Int) {
		sim = replay.makeSim()
		actions = replay.actions
		self.seat = seat
	}

	func next() -> Sample? {
		while cursor < actions.count {
			let action = actions[cursor]
			cursor += 1
			var sample: Sample?
			if sim.playerIndex == seat, let idx = sim.actionIndices(action) {
				sample = Self.sample(sim, idx)
			}
			_ = sim.reduce(action)
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
///
/// Two sources: a replay corpus on disk (BC — endless, epoch-shuffled) or an
/// in-memory episode list (RL — each consumed exactly once, on-policy; the
/// episode's advantage scales every label weight, so the graph's weighted CE
/// becomes the policy gradient). A window with `samples == 0` means the
/// episode list is exhausted.
final class Batcher {
	let b: Int
	let t: Int
	var n: Int { b * t }

	private let files: [URL]
	private var episodes: [(replay: Replay, seat: Int, scale: Float)] = []
	private let onePass: Bool
	private var rng: D20
	private var order: [Int] = []
	private var cursor = 0
	private var lanes: [Lane]

	private struct Lane {
		var stream: SampleStream?
		var scale: Float = 1
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
		onePass = false
		rng = D20(seed: seed)
		lanes = [Lane](repeating: Lane(), count: b)
	}

	init(episodes: [(replay: Replay, seat: Int, scale: Float)], b: Int, t: Int) {
		files = []
		self.episodes = episodes
		self.b = b
		self.t = t
		onePass = true
		rng = D20(seed: 0)
		lanes = [Lane](repeating: Lane(), count: b)
	}

	/// BC: streams are battle-seat pairs, shuffled anew each epoch.
	/// RL: the episode list, front to back, once.
	private func nextStream() -> (SampleStream, Float)? {
		if onePass {
			guard cursor < episodes.count else { return nil }
			let e = episodes[cursor]
			cursor += 1
			return (SampleStream(replay: e.replay, seat: e.seat), e.scale)
		}
		if cursor >= order.count {
			order = Array(0 ..< files.count * 2)
			for i in (1 ..< order.count).reversed() {
				order.swapAt(i, Int(rng.next() % UInt64(i + 1)))
			}
			cursor = 0
		}
		guard !order.isEmpty else { return nil }
		let id = order[cursor]
		cursor += 1
		guard let replay = try? Replay.read(files[id / 2]) else { return nil }
		return (SampleStream(replay: replay, seat: id % 2), 1)
	}

	func window() -> Window {
		let planeCount = SimObservation.planeSize * SimObservation.planeCount
		var w = Window(
			planes: [Float](repeating: 0, count: n * planeCount),
			globals: [Float](repeating: 0, count: n * SimObservation.globalCount),
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
				let next = nextStream()
				lanes[lane].stream = next?.0
				lanes[lane].scale = next?.1 ?? 1
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
				w.globals.replaceSubrange(i * SimObservation.globalCount ..< (i + 1) * SimObservation.globalCount, with: s.globals)
				w.kindMask.replaceSubrange(i * ActionSpace.kinds ..< (i + 1) * ActionSpace.kinds, with: s.kindMask)
				w.actorMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.actorMask)
				w.targetMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.targetMask)
				w.slotMask.replaceSubrange(i * ActionSpace.slots ..< (i + 1) * ActionSpace.slots, with: s.slotMask)
				let scale = lanes[lane].scale
				w.kind[i] = s.kind
				w.kindW[i] = scale
				if s.actor >= 0 {
					w.actor[i] = s.actor
					w.actorW[i] = scale
				}
				if s.target >= 0 {
					w.target[i] = s.target
					w.targetW[i] = scale
				}
				if s.slot >= 0 {
					w.slot[i] = s.slot
					w.slotW[i] = scale
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
}
