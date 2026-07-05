public extension TacticalSim {

	/// The single owner of the spatial invariant: a unit is alive, sits at
	/// `position[uid]`, and `unitsMap[position[uid]] == uid`, with its cargo
	/// riding along. Every site that moves, places, or removes a unit goes
	/// through `place`/`vacate`/`spawn` so the four structures can never drift.

	/// Relocate an on-map unit to `xy`: vacate the tile it currently holds, claim
	/// the new one, and drag any cargo to the same square. The tile it holds is
	/// cleared only when the map actually agrees it is there (`offMap` semantics),
	/// so `place` is also safe for a freshly-inserted unit whose stale `position`
	/// still reads `.zero`.
	mutating func place(_ uid: UID, at xy: XY) {
		if unitsMap[position[uid]] == uid {
			unitsMap[position[uid]] = .none
		}
		unitsMap[xy] = uid
		position[uid] = xy
		if cargo[uid] != .none {
			position[cargo[uid]] = xy
		}
	}

	/// Remove a unit from the map — it no longer occupies a tile (it died, or
	/// embarked into a transport). `position` is left untouched: a vacated unit's
	/// square is never read back through `unitsMap`. Guarded so vacating an
	/// already-off-map unit can't erase whoever now stands on its stale tile.
	mutating func vacate(_ uid: UID) {
		if unitsMap[position[uid]] == uid {
			unitsMap[position[uid]] = .none
		}
	}

	/// Insert a fresh unit and register it on the map at `xy`, returning its UID.
	/// The scenario-building counterpart to `place`: the shop, the factory, and
	/// tests create units through here.
	@discardableResult
	mutating func spawn(_ unit: Unit, at xy: XY) -> UID {
		let uid = units.insert(unit).uid
		cargo[uid.index] = .none
		place(uid, at: xy)
		return uid
	}
}
