import Testing
@testable import COR

struct RNGTests {

	@Test func randomDistribution() {
		var d20 = D20()
		var bins = [20 of UInt16](repeating: 0)

		let throwsCount = 20_000

		(0 ..< throwsCount).forEach { _ in
			bins[d20()] += 1
		}

		// Pearson's chi-squared goodness-of-fit against a uniform distribution.
		let expected = Double(throwsCount) / Double(bins.count)
		let chiSquared = bins.indices.reduce(0.0) { sum, i in
			let delta = Double(bins[i]) - expected
			return sum + delta * delta / expected
		}

		// Critical value for 19 degrees of freedom (20 bins - 1) at a very
		// generous p = 0.001. A genuinely uniform sample exceeds this less than
		// 0.1% of the time, so tail variance alone won't fail the test.
		let criticalValue = 43.82

		let str = bins.indices
			.map { i in "\(bins[i])" }
			.joined(separator: ", ")

		print("Bins: \(str)\nChi-squared: \(chiSquared), must be below \(criticalValue) for 19 dof")
		#expect(chiSquared < criticalValue)
	}

	@Test func damageCalculation() {
		var report = "Damage table:"
		var state = TacticalState.xs

		var u0 = Unit(model: .regular, country: .den)
		var u1 = Unit(model: .regular, country: .usa)
		u0.reset()
		u1.reset()

		state.sim.units.insert(u0)
		state.sim.units.insert(u1)
		state.sim.position[0] = XY(1, 1)
		state.sim.position[1] = XY(2, 2)

		let baseDif = Int(u0.atk(u1)) - Int(u1.def(u0))
		var dmgs: [(Float, UInt8, UInt8)] = []

		for atkMod in Int8(-15)...24 {
			state.sim.d20 = D20()
			var events: [TacticalEvent] = []
			var min = UInt8.max, max = UInt8.min
			let sum: UInt32 = (0 ..< 512).reduce(0) { acc, _ in
				state.sim.units[0] = u0
				state.sim.units[1] = u1
				state.sim.fire(src: UID(0), dst: UID(1), defMod: -atkMod, into: &events)
				let dmg = state.sim.units[1].maxHP - state.sim.units[1].hp
				if dmg > max { max = dmg }
				if dmg < min { min = dmg }
				return acc + UInt32(dmg)
			}

			let avg = Float(sum) / 512
			let dif = baseDif + Int(atkMod)
			if dif >= 0 { #expect(avg > 0) }
			dmgs.append((avg, min, max))
			report += "\ndif: \(dif) dmg: \(avg) \(min)...\(max)"
		}

		#expect(dmgs.first!.0 < dmgs.last!.0)
		print(report)
	}
}

extension TacticalState {

	static var xs: Self {
		var map = Map<32, Terrain>(size: 4, zero: .field)
		let cities: [(XY, Country)] = [
			(XY(0, 0), .den),
			(XY(3, 3), .usa),
		]
		cities.forEach { x, _ in map[x] = .city }

		let players: [Player] = [
			Player(country: .den, type: .human, prestige: 0xF00),
			Player(country: .usa, type: .human, prestige: 0xF00),
		]

		return TacticalState(
			map: map,
			players: players,
			cities: cities,
			units: []
		)
	}
}
