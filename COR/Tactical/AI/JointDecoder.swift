import Foundation

/// Diagnostic complete-action decoding (`Train eval --decoder`): the same
/// forward pass as `traced`, decoded three ways — the shipping greedy
/// hierarchy, exact MAP over masked conditional log-probabilities, and a beam
/// over (kind, actor) prefixes. Advances the LSTM exactly once per call; the
/// target/slot heads are kind-independent, so they run once per unique actor
/// and only the legality masks differ per kind.
public extension LSTMPolicy {

	struct JointDecision {
		public var greedy: TacticalAction = .end
		public var exact: TacticalAction = .end
		public var beam: TacticalAction = .end
		/// Greedy's kind, but actor and target/slot decoded jointly within it.
		public var kindLocal: TacticalAction = .end
		public var prefixes = 0
		public var legalActions = 1
	}

	mutating func jointDecision(for sim: borrowing TacticalSim, beamWidth: Int = 8) -> JointDecision {
		if sim.turn != lastTurn {
			if sim.turn < lastTurn { reset() }
			lastTurn = sim.turn
			actionsThisTurn = 0
		}
		actionsThisTurn += 1
		guard actionsThisTurn <= Self.maxActionsPerTurn else {
			return JointDecision(prefixes: 0, legalActions: 0)
		}

		let trunk = step(sim.observation())
		let masks = sim.actionMasks()
		let kinds = masks.kinds
		let kindLogits = fc(h, "kind")
		let kindLP = Self.logSoftmax(kindLogits, kinds)

		let proj = fc(h, "actor.proj")
		let actorLogits = tileHead(trunk, per: proj, prefix: "actor")

		struct Prefix {
			var kind: Int
			var lp: Float
			var complete: Float
			var action: TacticalAction
		}
		let endLP = kindLP[ActionSpace.Kind.end.rawValue]
		var prefixes = [Prefix(kind: ActionSpace.Kind.end.rawValue, lp: endLP, complete: endLP, action: .end)]
		var targetCache = [Int: [Float]]()
		var slotCache = [Int: [Float]]()
		var d = JointDecision()

		for k in 0 ..< ActionSpace.kinds where kinds[k] {
			guard let kind = ActionSpace.Kind(rawValue: k), kind != .end else { continue }
			let actorLP = Self.logSoftmax(actorLogits, masks.actors[k])

			for a in 0 ..< ActionSpace.tiles where masks.actors[k][a] {
				let lp = kindLP[k] + actorLP[a]
				var p = Prefix(kind: k, lp: lp, complete: -.infinity, action: .end)

				switch kind {
				case .resupply:
					p.complete = lp
					p.action = sim.action(ActionIndices(kind: .resupply, actor: a)) ?? .end
					d.legalActions += 1
				case .move, .embark, .disembark, .attack:
					if targetCache[a] == nil { targetCache[a] = targetHead(trunk, actor: a) }
					let logits = targetCache[a]!
					let mask = sim.targetMask(kind, actor: a)
					if let t = Self.argmax(logits, mask) {
						p.complete = lp + Self.logSoftmax(logits, mask)[t]
						p.action = sim.action(ActionIndices(kind: kind, actor: a, target: t)) ?? .end
					}
					d.legalActions += mask.reduce(0) { $0 + ($1 ? 1 : 0) }
				case .purchase:
					if slotCache[a] == nil { slotCache[a] = slotHead(trunk, actor: a) }
					let logits = slotCache[a]!
					let mask = sim.slotMask(actor: a)
					if let s = Self.argmax(logits, mask) {
						p.complete = lp + Self.logSoftmax(logits, mask)[s]
						p.action = sim.action(ActionIndices(kind: .purchase, actor: a, slot: s)) ?? .end
					}
					d.legalActions += mask.reduce(0) { $0 + ($1 ? 1 : 0) }
				case .end:
					break
				}
				prefixes.append(p)
			}
		}
		d.prefixes = prefixes.count

		// Greedy, stage for stage the `traced` argmax path on the same heads.
		if let k = Self.argmax(kindLogits, kinds),
		   let kind = ActionSpace.Kind(rawValue: k), kind != .end,
		   let actor = Self.argmax(actorLogits, masks.actors[k]) {
			switch kind {
			case .move, .embark, .disembark, .attack:
				if let t = Self.argmax(targetCache[actor]!, sim.targetMask(kind, actor: actor)) {
					d.greedy = sim.action(ActionIndices(kind: kind, actor: actor, target: t)) ?? .end
				}
			case .purchase:
				if let s = Self.argmax(slotCache[actor]!, sim.slotMask(actor: actor)) {
					d.greedy = sim.action(ActionIndices(kind: .purchase, actor: actor, slot: s)) ?? .end
				}
			case .resupply:
				d.greedy = sim.action(ActionIndices(kind: .resupply, actor: actor)) ?? .end
			case .end:
				break
			}
		}

		var best: Float = -.infinity
		for p in prefixes where p.complete > best {
			best = p.complete
			d.exact = p.action
		}

		if let k = Self.argmax(kindLogits, kinds) {
			best = -.infinity
			for p in prefixes where p.kind == k && p.complete > best {
				best = p.complete
				d.kindLocal = p.action
			}
		}

		let ranked = prefixes.indices.sorted { a, b in
			prefixes[a].lp == prefixes[b].lp ? a < b : prefixes[a].lp > prefixes[b].lp
		}
		best = -.infinity
		for i in ranked.prefix(beamWidth) where prefixes[i].complete > best {
			best = prefixes[i].complete
			d.beam = prefixes[i].action
		}

		return d
	}

	// MARK: - Head evaluation shared with `traced`'s math

	internal func targetHead(_ trunk: [Float], actor: Int) -> [Float] {
		let actorTrunk = Array(trunk[actor * LSTMWeights.trunk ..< (actor + 1) * LSTMWeights.trunk])
		let cond = relu(fc(h + actorTrunk, "target.cond"))
		return tileHead(trunk, per: cond, prefix: "target")
	}

	internal func slotHead(_ trunk: [Float], actor: Int) -> [Float] {
		let actorTrunk = Array(trunk[actor * LSTMWeights.trunk ..< (actor + 1) * LSTMWeights.trunk])
		return fc(relu(fc(h + actorTrunk, "slot.fc1")), "slot.fc2")
	}

	/// Masked log-softmax; `-inf` where the mask is unset.
	static func logSoftmax(_ logits: [Float], _ mask: [Bool]) -> [Float] {
		var out = [Float](repeating: -.infinity, count: logits.count)
		var mx = -Float.infinity
		for i in logits.indices where mask[i] { mx = max(mx, logits[i]) }
		guard mx > -.infinity else { return out }
		var sum: Float = 0
		for i in logits.indices where mask[i] { sum += expf(logits[i] - mx) }
		let lse = mx + logf(sum)
		for i in logits.indices where mask[i] { out[i] = logits[i] - lse }
		return out
	}
}
