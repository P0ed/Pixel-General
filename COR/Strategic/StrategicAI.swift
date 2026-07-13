public extension StrategicSim {

	/// Plays one deterministic strategic turn for every non-human country.
	/// Each country musters at most one army, advances toward the nearest enemy
	/// province, and only attacks when its local strength is at least 3:1.
	mutating func runStrategicAI() {
		guard battle == nil else { return }
		for country in Country.playable where country != player.country {
			guard ownsLand(country) else { continue }
			musterAIArmy(for: country)
			for slot in 0 ..< 4 where armyIsActive(slot, for: country) {
				actAIArmy(ArmyID(country: country, slot: slot))
			}
			refreshMovement(for: country)
		}
	}
}

private extension StrategicSim {

	func ownsLand(_ country: Country) -> Bool {
		for xy in owner.indices where owner[xy] == country { return true }
		return false
	}

	mutating func musterAIArmy(for country: Country) {
		guard freeArmySlot(for: country) != nil else { return }
		var best: XY?
		var bestDistance = Int.max
		for xy in owner.indices where canFound(at: xy, for: country) {
			let distance = enemyDistance(from: xy, for: country)
			if distance < bestDistance { best = xy; bestDistance = distance }
		}
		guard let best else { return }

		var templates = [Unit].small(country)
		templates.modifyEach { unit in unit.reset() }
		let roster = [16 of Unit](head: Array(templates.prefix(16)), tail: .empty)
		found(at: best, for: country, units: roster)
	}

	mutating func actAIArmy(_ id: ArmyID) {
		guard army(id).active, army(id).mp > 0, hasCoreForce(id.index, for: id.country) else { return }
		if attackIfAdvantaged(id) { return }

		let origin = army(id).position
		let range = reachable(by: id.index, for: id.country)
		var destination: XY?
		var bestDistance = enemyDistance(from: origin, for: id.country)
		for xy in owner.indices where range[xy] {
			let distance = enemyDistance(from: xy, for: id.country)
			if distance < bestDistance {
				destination = xy
				bestDistance = distance
			}
		}
		if let destination,
			let steps = marchCost(by: id.index, for: id.country, to: destination)
		{
			let countryIndex = Int(id.country.rawValue)
			armies[countryIndex][id.index].position = destination
			armies[countryIndex][id.index].mp -= min(steps, armies[countryIndex][id.index].mp)
			_ = attackIfAdvantaged(id)
		}
	}

	mutating func attackIfAdvantaged(_ id: ArmyID) -> Bool {
		let position = army(id).position
		let n4 = position.n4
		for index in 0 ..< n4.count {
			let target = n4[index]
			guard canAttack(target, with: id),
				hasLocalAdvantage(id, attacking: target)
			else { continue }
			_ = autoResolveAttack(at: target, by: id)
			return true
		}
		return false
	}

	func enemyDistance(from origin: XY, for country: Country) -> Int {
		var best = Int.max
		for xy in owner.indices {
			let occupant = owner[xy]
			guard occupant != .none, occupant.team != country.team else { continue }
			best = min(best, origin.stepDistance(to: xy))
		}
		return best
	}

	mutating func refreshMovement(for country: Country) {
		let countryIndex = Int(country.rawValue)
		for slot in 0 ..< 4 where armies[countryIndex][slot].active {
			armies[countryIndex][slot].mp = Army.moveSpeed
		}
	}
}
