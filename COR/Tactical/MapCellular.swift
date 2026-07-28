/// Configuration for the map editor's height automaton.
///
/// The map carries only three discrete elevations (`Terrain.elevationLevel`),
/// which is exactly the state space a three-colour cellular automaton wants.
/// One engine hosts three transition rules:
///
/// - `.terrace` — a monotone-drift voter model. Cells rise towards higher
///   neighbours and erode towards lower ones, so the two thresholds sweep from
///   smoothing through growth and erosion into a metastable coarsening regime.
/// - `.cyclic` — the classic cyclic (Greenberg–Hastings) automaton over
///   `0 → 1 → 2 → 0`. From a disordered start it self-organises into rotating
///   spiral cores and expanding ring waves.
/// - `.ridges` — short-range activation against long-range inhibition, using
///   the inner `n8` ring against the outer `r12` ring. Produces striped ridge
///   labyrinths and regularly spaced massifs.
///
/// The grid is a torus in every rule, so patterns tile seamlessly and no cell
/// sees a truncated neighbourhood.
public struct Cellular: Hashable, Sendable {

	public enum Kind: UInt8, Hashable, Sendable, CaseIterable {
		case terrace, cyclic, ridges
	}

	public var kind: Kind = .terrace

	/// `0` = `n4`, `1` = `n8`, `2` = `n20`. Ignored by `.ridges`, whose two
	/// rings are fixed by the rule.
	public var neighborhood: UInt8 = 1

	/// Knob `0…3`, mapped to a real neighbour count by `riseCount`.
	public var rise: UInt8 = 1

	/// Knob `0…3`, mapped to a real neighbour count by `fallCount`. Unused by
	/// `.cyclic`, which only has an excitation threshold.
	public var fall: UInt8 = 1

	/// Knob `0…3`; each step nudges a cell by ±1 with probability `noise / 16`.
	/// This is what keeps `.terrace` from freezing into a fixed point and what
	/// gives every boundary its organic wiggle.
	public var noise: UInt8 = 1

	public init() {}
}

public extension Cellular {

	/// Number of cells in the selected neighbourhood.
	var cells: Int {
		switch neighborhood {
		case 0: 4
		case 2: 20
		default: 8
		}
	}

	/// `.terrace` thresholds the *sum* of neighbour levels, which runs
	/// `0 ... 2 * cells` and is neutral at `cells` (an all-level-1
	/// neighbourhood). The knobs widen the band of sums that leave a cell
	/// alone — that hysteresis is what lets structure persist instead of every
	/// cell flipping every generation.
	var riseSum: Int { cells + margin(rise) }
	var fallSum: Int { cells - margin(fall) }

	/// Rounded rather than truncated so the four knob positions stay distinct
	/// on the small `n4` neighbourhood, where a truncating scale collapses
	/// three of them onto the same band.
	func margin(_ knob: UInt8) -> Int {
		1 + (Int(min(knob, 3)) * cells + 4) / 8
	}

	/// `.cyclic` thresholds how many neighbours already hold the next colour.
	/// The useful band is narrow and centred on a third of the neighbourhood —
	/// that is the expected count on a scattered map, so it is where fronts
	/// propagate. Well above it the automaton freezes on the first generation,
	/// so the top knob positions are clamped rather than left dead.
	var riseCount: Int {
		let k = Int(min(rise, 3))
		return switch neighborhood {
		case 0: 1 + (k + 1) / 2 // 1, 2, 2, 3 of 4
		case 2: 6 + k           // 6, 7, 8, 9 of 20
		default: 2 + min(k, 2)  // 2, 3, 4, 4 of 8
		}
	}

	/// `.ridges` thresholds the activator/inhibitor score, not a neighbour
	/// count. The score `3a - 2b` is zero-mean and spans ±48.
	var riseScore: Int { 4 + Int(min(rise, 3)) * 5 }
	var fallScore: Int { 4 + Int(min(fall, 3)) * 5 }
}

public extension Map<32, Terrain> {

	/// Runs `steps` synchronous automaton generations over the elevation field.
	///
	/// Water, settlements and roads are read as ordinary level-0 ground. A tile
	/// is rewritten only when its level actually moved, so lowland structures
	/// the automaton never lifts survive bit-identical; anything it does lift
	/// collapses to open ground and does not come back.
	mutating func cellular(_ rule: Cellular, steps: Int, d20: inout D20) {
		guard steps > 0 else { return }

		let n = size
		var level = [UInt8](repeating: 0, count: n * n)
		var wooded = [Bool](repeating: false, count: n * n)
		for xy in indices {
			let terrain = self[xy]
			level[xy.y * n + xy.x] = UInt8(terrain.elevationLevel)
			wooded[xy.y * n + xy.x] = terrain.isWooded
		}

		let original = level
		var next = level

		for _ in 0 ..< steps {
			for xy in indices {
				next[xy.y * n + xy.x] = rule.step(at: xy, level, n)
			}
			if rule.noise > 0 {
				rule.perturb(&next, &d20)
			}
			swap(&level, &next)
		}

		for xy in indices {
			let i = xy.y * n + xy.x
			guard level[i] != original[i] else { continue }
			self[xy] = .ground(Int(level[i]), wooded: wooded[i])
		}
	}

	/// Random 0…2 elevation across the map — the disordered start the cyclic
	/// and ridge rules need before their patterns emerge.
	mutating func scatterHeights(d20: inout D20) {
		for xy in indices {
			let terrain = self[xy]
			let level = Int(d20.next() % 3)
			guard level != terrain.elevationLevel else { continue }
			self[xy] = .ground(level, wooded: terrain.isWooded)
		}
	}

	/// Drops every tile to level 0, keeping tree cover.
	mutating func flattenHeights() {
		for xy in indices {
			let terrain = self[xy]
			guard terrain.elevationLevel != 0 else { continue }
			self[xy] = .ground(0, wooded: terrain.isWooded)
		}
	}
}

private extension Cellular {

	func step(at xy: XY, _ level: [UInt8], _ size: Int) -> UInt8 {
		func forEachNeighbor(_ body: (UInt8) -> Void) {
			switch neighborhood {
			case 0:
				let ns = xy.n4
				for i in ns.indices {
					let n = ns[i].wrapped(size)
					body(level[n.y * size + n.x])
				}
			case 2:
				let ns = xy.n20
				for i in ns.indices {
					let n = ns[i].wrapped(size)
					body(level[n.y * size + n.x])
				}
			default:
				let ns = xy.n8
				for i in ns.indices {
					let n = ns[i].wrapped(size)
					body(level[n.y * size + n.x])
				}
			}
		}

		let h = level[xy.y * size + xy.x]

		switch kind {
		case .terrace:
			var sum = 0
			forEachNeighbor { l in sum += Int(l) }
			if sum >= riseSum { return min(2, h + 1) }
			if sum <= fallSum { return h > 0 ? h - 1 : 0 }
			return h

		case .cyclic:
			let want = (h + 1) % 3
			var ahead = 0
			forEachNeighbor { l in
				if l == want { ahead += 1 }
			}
			return ahead >= riseCount ? want : h

		case .ridges:
			var inner = 0
			var outer = 0
			let n8 = xy.n8
			for i in n8.indices {
				let n = n8[i].wrapped(size)
				inner += Int(level[n.y * size + n.x])
			}
			let r12 = xy.r12
			for i in r12.indices {
				let n = r12[i].wrapped(size)
				outer += Int(level[n.y * size + n.x])
			}
			let score = 3 * inner - 2 * outer
			if score >= riseScore { return min(2, h + 1) }
			if score <= -fallScore { return h > 0 ? h - 1 : 0 }
			return h
		}
	}

	/// A ±1 nudge with probability `noise / 16`, split evenly between the two
	/// directions. One draw per cell keeps the stream reproducible.
	func perturb(_ level: inout [UInt8], _ d20: inout D20) {
		let p = UInt64(noise)
		for i in level.indices {
			let r = d20.next() % 32
			if r < p {
				level[i] = min(2, level[i] + 1)
			} else if r < p * 2 {
				level[i] = level[i] > 0 ? level[i] - 1 : 0
			}
		}
	}
}
