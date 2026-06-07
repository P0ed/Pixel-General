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
		for atk in UInt8.min...30 {
			let inf = Unit.make(atk: 1 + atk, def: 11)
			let u0 = inf.country(.den)
			let u1 = inf.country(.usa)

			state.units.insert(u0)
			state.units.insert(u1)
			state.position[0] = XY(1, 1)
			state.position[1] = XY(2, 2)

			let dmg: [512 of [2 of UInt8]] = .init { i in
				state.units[0] = u0
				state.units[1] = u1
				_ = state.reduce(.attack(UID(0), UID(1)))

				return [
					state.units[1].maxHP - state.units[1].hp,
					state.units[0].maxHP - state.units[0].hp,
				]
			}

			let sum: [2 of UInt32] = dmg.reduce(into: .init(repeating: 0)) { r, dmg in
				r[0] += UInt32(dmg[0])
				r[1] += UInt32(dmg[1])
			}
			let avg0 = Float(sum[0]) / Float(dmg.count)
			let avg1 = Float(sum[1]) / Float(dmg.count)
			let dif = Int(u0.atk(u1)) - Int(u1.def(u0))

			if dif >= 0 { #expect(sum[0] > sum[1]) }

			report += "\natk - def: \(dif) dmg: \(avg0), retaliation: \(avg1)"
		}
		print(report)
	}
}

extension Unit {

	static func make(atk: UInt8, def: UInt8) -> Unit {
		var u = Unit(type: .inf, rng: 1, ini: 5, softAtk: atk, groundDef: def)
		u.reset()
		return u
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
