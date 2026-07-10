/// The policy's factored action interface.
///
/// A `TacticalAction` maps to (kind, actor tile, target tile, shop slot) head
/// indices and back, and the legality masks mirror the reducer guards — so a
/// masked action can never silently no-op through `reduce`. Tiles index the
/// fixed 32-stride grid of `SimObservation` regardless of the actual map size
/// (`x + y * 32`); UIDs are deliberately absent from the interface because
/// they are arbitrary storage slots the network cannot observe.
public enum ActionSpace {
	public static let kinds = 7
	public static let tiles = SimObservation.planeSize
	/// Shop head capacity. `Shop.units` tops out at 20 rows; the headroom
	/// (auxilia rows before predeploy) stays — trained policy heads and the
	/// `Train/` tensor shapes are sized by it.
	public static let slots = 40

	@frozen public enum Kind: Int, CaseIterable {
		case move, embark, disembark, attack, resupply, purchase, end
	}

	public static func tile(_ xy: XY) -> Int { xy.x + xy.y * SimObservation.side }
	public static func xy(_ tile: Int) -> XY { XY(tile % SimObservation.side, tile / SimObservation.side) }
}

/// Head indices of one concrete action; `-1` marks heads the kind doesn't use.
public struct ActionIndices: Equatable {
	public var kind: ActionSpace.Kind
	public var actor: Int
	public var target: Int
	public var slot: Int

	public init(kind: ActionSpace.Kind, actor: Int = -1, target: Int = -1, slot: Int = -1) {
		self.kind = kind
		self.actor = actor
		self.target = target
		self.slot = slot
	}
}

/// Kind and actor legality for the current acting player. Target and slot
/// masks depend on the chosen actor and are computed on demand
/// (`targetMask(_:actor:)` / `slotMask(actor:)`).
public struct ActionMasks {
	/// `kinds × tiles`; a set bit means the unit (or shop tile) at that tile
	/// has at least one legal target/slot for the kind.
	public var actors: [[Bool]]

	/// A kind is available iff some actor bit is set; `.end` always is.
	public var kinds: [Bool] {
		var k = actors.map { mask in mask.contains(true) }
		k[ActionSpace.Kind.end.rawValue] = true
		return k
	}
}

public extension TacticalSim {

	// MARK: - TacticalAction ↔ head indices

	/// Head indices for `action` in the *current* state (unit positions are
	/// looked up before the action is applied). `nil` for `.takeover`, which
	/// is multiplayer bookkeeping no policy may emit.
	func actionIndices(_ action: TacticalAction) -> ActionIndices? {
		switch action {
		case .move(let u, let xy):
			ActionIndices(kind: .move, actor: ActionSpace.tile(position[u]), target: ActionSpace.tile(xy))
		case .embark(let u, let t):
			ActionIndices(kind: .embark, actor: ActionSpace.tile(position[u]), target: ActionSpace.tile(position[t]))
		case .disembark(let t, let xy):
			ActionIndices(kind: .disembark, actor: ActionSpace.tile(position[t]), target: ActionSpace.tile(xy))
		case .attack(let s, let d):
			ActionIndices(kind: .attack, actor: ActionSpace.tile(position[s]), target: ActionSpace.tile(position[d]))
		case .resupply(let u):
			ActionIndices(kind: .resupply, actor: ActionSpace.tile(position[u]))
		case .purchase(let idx, let xy):
			ActionIndices(kind: .purchase, actor: ActionSpace.tile(xy), slot: idx)
		case .end:
			ActionIndices(kind: .end)
		case .takeover:
			nil
		}
	}

	/// Decodes head indices back into a concrete action; `nil` when the tiles
	/// don't resolve to units (masking prevents that for legal indices).
	func action(_ idx: ActionIndices) -> TacticalAction? {
		switch idx.kind {
		case .move:
			uidAt(ActionSpace.xy(idx.actor)).map { u in .move(u, ActionSpace.xy(idx.target)) }
		case .embark:
			uidAt(ActionSpace.xy(idx.actor)).flatMap { u in
				uidAt(ActionSpace.xy(idx.target)).map { t in .embark(u, t) }
			}
		case .disembark:
			uidAt(ActionSpace.xy(idx.actor)).map { t in .disembark(t, ActionSpace.xy(idx.target)) }
		case .attack:
			uidAt(ActionSpace.xy(idx.actor)).flatMap { s in
				uidAt(ActionSpace.xy(idx.target)).map { d in .attack(s, d) }
			}
		case .resupply:
			uidAt(ActionSpace.xy(idx.actor)).map { u in .resupply(u) }
		case .purchase:
			.purchase(idx.slot, ActionSpace.xy(idx.actor))
		case .end:
			.end
		}
	}

	// MARK: - Legality masks

	/// Kind/actor legality for the acting player. Built from the same `can*`
	/// predicates that guard the corresponding reducers (`canMove`,
	/// `canEmbark`, `canDisembark`, `canAttack`, `canResupply`, `canBuy`) —
	/// so every masked action mutates the state.
	func actionMasks() -> ActionMasks {
		var actors = [[Bool]](
			repeating: [Bool](repeating: false, count: ActionSpace.tiles),
			count: ActionSpace.kinds
		)
		let country = country

		units.forEachAlive { i, u in
			guard u.country == country, !offMap(unit: i.uid) else { return }
			let uid = i.uid
			let tile = ActionSpace.tile(position[i])

			if canMove(unit: uid), hasMoveTarget(uid) {
				actors[ActionSpace.Kind.move.rawValue][tile] = true
			}
			if hasEmbarkTarget(uid) {
				actors[ActionSpace.Kind.embark.rawValue][tile] = true
			}
			if u[.transport], cargo[uid] != .none, hasDisembarkTarget(uid) {
				actors[ActionSpace.Kind.disembark.rawValue][tile] = true
			}
			if u.canAttack, u.ammo > 0, hasAttackTarget(uid) {
				actors[ActionSpace.Kind.attack.rawValue][tile] = true
			}
			if canResupply(unit: uid) {
				actors[ActionSpace.Kind.resupply.rawValue][tile] = true
			}
		}

		settlements.forEach { xy in
			guard control[xy] == country, canBuy(at: xy) else { return }
			actors[ActionSpace.Kind.purchase.rawValue][ActionSpace.tile(xy)] = true
		}

		return ActionMasks(actors: actors)
	}

	/// Legal target tiles for `kind` once the actor tile is chosen.
	/// `.resupply`/`.purchase`/`.end` use no target head — all-false mask.
	func targetMask(_ kind: ActionSpace.Kind, actor: Int) -> [Bool] {
		var mask = [Bool](repeating: false, count: ActionSpace.tiles)
		guard let uid = uidAt(ActionSpace.xy(actor)) else { return mask }

		switch kind {
		case .move:
			let mv = moves(for: uid)
			for xy in mv.moves.indices where mv.moves[xy] > 0 && xy != mv.start {
				mask[ActionSpace.tile(xy)] = true
			}
		case .attack:
			units.forEachAlive { j, _ in
				if canAttack(src: uid, dst: j.uid) {
					mask[ActionSpace.tile(position[j])] = true
				}
			}
		case .embark:
			let n4 = position[uid].n4
			for i in n4.indices where isEmbarkTarget(uid, n4[i]) {
				mask[ActionSpace.tile(n4[i])] = true
			}
		case .disembark:
			let n4 = position[uid].n4
			for i in n4.indices where isDisembarkTarget(uid, n4[i]) {
				mask[ActionSpace.tile(n4[i])] = true
			}
		case .resupply, .purchase, .end:
			break
		}
		return mask
	}

	/// Legal shop slots for a `.purchase` at the actor tile. One `shopUnits`
	/// build; the per-slot rule is `canBuy(slot:at:)`.
	func slotMask(actor: Int) -> [Bool] {
		var mask = [Bool](repeating: false, count: ActionSpace.slots)
		let shop = shopUnits(at: ActionSpace.xy(actor))
		for (i, u) in shop.enumerated() where i < ActionSpace.slots && u.cost <= player.prestige {
			mask[i] = true
		}
		return mask
	}

	// MARK: - Actor predicates

	private func hasMoveTarget(_ uid: UID) -> Bool {
		moves(for: uid).hasMoves
	}

	private func hasAttackTarget(_ uid: UID) -> Bool {
		units.firstMapAlive { j, _ in
			canAttack(src: uid, dst: j.uid) ? true : nil
		} ?? false
	}

	private func hasEmbarkTarget(_ uid: UID) -> Bool {
		position[uid].n4.contains { xy in isEmbarkTarget(uid, xy) }
	}

	private func hasDisembarkTarget(_ uid: UID) -> Bool {
		position[uid].n4.contains { xy in isDisembarkTarget(uid, xy) }
	}

	private func isEmbarkTarget(_ uid: UID, _ xy: XY) -> Bool {
		uidAt(xy).map { tid in canEmbark(unit: uid, transport: tid) } ?? false
	}

	private func isDisembarkTarget(_ uid: UID, _ xy: XY) -> Bool {
		canDisembark(unit: uid, to: xy)
	}
}
