import Foundation
import COR

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
/// order — the teacher (the heuristic AI) drove both seats, so every action of the
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
	private var buf: Window

	private struct Lane {
		var stream: SampleStream?
		var scale: Float = 1
		var id: Int32 = -1
		var h = [Float](repeating: 0, count: LSTMWeights.hidden)
		var c = [Float](repeating: 0, count: LSTMWeights.hidden)
		var hr = [Float](repeating: 0, count: LSTMWeights.hidden)
		var cr = [Float](repeating: 0, count: LSTMWeights.hidden)
	}

	/// One `Batcher` owns a single `Window` buffer that `window()` mutates and
	/// returns — CoW makes that safe as long as callers drop the window before
	/// the next `window()` call (all trainers do). Retaining a *large* array
	/// (`planes`) across calls silently triggers a full copy on the next
	/// window — don't; small snapshots (`epi`, `kindW`) copy cheaply, which is
	/// exactly the semantics the PPO read-pass cache needs.
	///
	/// Padded rows (zero weight, `epi == -1`) keep **stale** planes/globals/
	/// masks/labels from earlier windows — harmless: the zero weights exclude
	/// them from every loss/accuracy term, and dead-lane `hT`/`cT` are never
	/// carried (`carry()` skips lanes with `stream == nil`).
	struct Window {
		var planes, globals: [Float]
		var kind, actor, target, slot: [Int32]
		var kindW, actorW, targetW, slotW: [Float]
		var kindMask, actorMask, targetMask, slotMask: [Float]
		var h0, c0: [Float]
		/// Stream ordinal per sample (−1 on padding) — the PPO trainer maps
		/// samples back to their episode's return/advantage with it.
		var epi: [Int32]
		/// A second recurrent state, carried for the PPO KL-anchor's frozen
		/// reference branch (which must run its *own* h/c under its own
		/// weights); zeros and unused everywhere else.
		var h0r, c0r: [Float]
		var samples = 0

		init(b: Int, t: Int) {
			let n = b * t
			planes = [Float](repeating: 0, count: n * SimObservation.planeSize * SimObservation.planeCount)
			globals = [Float](repeating: 0, count: n * SimObservation.globalCount)
			kind = [Int32](repeating: 0, count: n)
			actor = [Int32](repeating: 0, count: n)
			target = [Int32](repeating: 0, count: n)
			slot = [Int32](repeating: 0, count: n)
			kindW = [Float](repeating: 0, count: n)
			actorW = [Float](repeating: 0, count: n)
			targetW = [Float](repeating: 0, count: n)
			slotW = [Float](repeating: 0, count: n)
			kindMask = [Float](repeating: 0, count: n * ActionSpace.kinds)
			actorMask = [Float](repeating: 0, count: n * ActionSpace.tiles)
			targetMask = [Float](repeating: 0, count: n * ActionSpace.tiles)
			slotMask = [Float](repeating: 0, count: n * ActionSpace.slots)
			h0 = [Float](repeating: 0, count: b * LSTMWeights.hidden)
			c0 = [Float](repeating: 0, count: b * LSTMWeights.hidden)
			epi = [Int32](repeating: -1, count: n)
			h0r = [Float](repeating: 0, count: b * LSTMWeights.hidden)
			c0r = [Float](repeating: 0, count: b * LSTMWeights.hidden)
		}
	}

	init(files: [URL], b: Int, t: Int, seed: UInt64) {
		self.files = files
		self.b = b
		self.t = t
		onePass = false
		rng = D20(seed: seed)
		lanes = [Lane](repeating: Lane(), count: b)
		buf = Window(b: b, t: t)
	}

	init(episodes: [(replay: Replay, seat: Int, scale: Float)], b: Int, t: Int) {
		files = []
		self.episodes = episodes
		self.b = b
		self.t = t
		onePass = true
		rng = D20(seed: 0)
		lanes = [Lane](repeating: Lane(), count: b)
		buf = Window(b: b, t: t)
	}

	/// BC: streams are battle-seat pairs, shuffled anew each epoch.
	/// RL: the episode list, front to back, once.
	private func nextStream() -> (SampleStream, Float, Int32)? {
		if onePass {
			guard cursor < episodes.count else { return nil }
			let e = episodes[cursor]
			cursor += 1
			return (SampleStream(replay: e.replay, seat: e.seat), e.scale, Int32(cursor - 1))
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
		return (SampleStream(replay: replay, seat: id % 2), 1, Int32(id))
	}

	func window() -> Window {
		let planeCount = SimObservation.planeSize * SimObservation.planeCount
		// Reset only what correctness needs (see `Window`'s doc): the weights
		// and `epi` gate everything else; h0/c0/h0r/c0r are fully rewritten by
		// the lane loop below.
		buf.samples = 0
		for i in 0 ..< n {
			buf.kindW[i] = 0
			buf.actorW[i] = 0
			buf.targetW[i] = 0
			buf.slotW[i] = 0
			buf.epi[i] = -1
		}

		for lane in 0 ..< b {
			if lanes[lane].stream == nil {
				let next = nextStream()
				lanes[lane].stream = next?.0
				lanes[lane].scale = next?.1 ?? 1
				lanes[lane].id = next?.2 ?? -1
				lanes[lane].h = [Float](repeating: 0, count: LSTMWeights.hidden)
				lanes[lane].c = [Float](repeating: 0, count: LSTMWeights.hidden)
				lanes[lane].hr = [Float](repeating: 0, count: LSTMWeights.hidden)
				lanes[lane].cr = [Float](repeating: 0, count: LSTMWeights.hidden)
			}
			for i in 0 ..< LSTMWeights.hidden {
				buf.h0[lane * LSTMWeights.hidden + i] = lanes[lane].h[i]
				buf.c0[lane * LSTMWeights.hidden + i] = lanes[lane].c[i]
				buf.h0r[lane * LSTMWeights.hidden + i] = lanes[lane].hr[i]
				buf.c0r[lane * LSTMWeights.hidden + i] = lanes[lane].cr[i]
			}

			for step in 0 ..< t {
				guard let s = lanes[lane].stream?.next() else {
					lanes[lane].stream = nil		// pad the rest; fresh stream next window
					break
				}
				let i = step * b + lane
				// Equal-length replaces mutate in place — no reallocation.
				buf.planes.replaceSubrange(i * planeCount ..< (i + 1) * planeCount, with: s.planes)
				buf.globals.replaceSubrange(i * SimObservation.globalCount ..< (i + 1) * SimObservation.globalCount, with: s.globals)
				buf.kindMask.replaceSubrange(i * ActionSpace.kinds ..< (i + 1) * ActionSpace.kinds, with: s.kindMask)
				buf.actorMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.actorMask)
				buf.targetMask.replaceSubrange(i * ActionSpace.tiles ..< (i + 1) * ActionSpace.tiles, with: s.targetMask)
				buf.slotMask.replaceSubrange(i * ActionSpace.slots ..< (i + 1) * ActionSpace.slots, with: s.slotMask)
				let scale = lanes[lane].scale
				buf.epi[i] = lanes[lane].id
				buf.kind[i] = s.kind
				buf.kindW[i] = scale
				if s.actor >= 0 {
					buf.actor[i] = s.actor
					buf.actorW[i] = scale
				}
				if s.target >= 0 {
					buf.target[i] = s.target
					buf.targetW[i] = scale
				}
				if s.slot >= 0 {
					buf.slot[i] = s.slot
					buf.slotW[i] = scale
				}
				buf.samples += 1
			}
		}
		return buf
	}

	/// Carries the window-final hidden state into each lane that still has a
	/// live stream (`h`/`c` are `[b * hidden]`, lane-major). `hr`/`cr` carry
	/// the PPO reference branch's independent state the same way.
	func carry(h: [Float], c: [Float], hr: [Float]? = nil, cr: [Float]? = nil) {
		for lane in 0 ..< b where lanes[lane].stream != nil {
			for i in 0 ..< LSTMWeights.hidden {
				lanes[lane].h[i] = h[lane * LSTMWeights.hidden + i]
				lanes[lane].c[i] = c[lane * LSTMWeights.hidden + i]
				if let hr { lanes[lane].hr[i] = hr[lane * LSTMWeights.hidden + i] }
				if let cr { lanes[lane].cr[i] = cr[lane * LSTMWeights.hidden + i] }
			}
		}
	}
}
