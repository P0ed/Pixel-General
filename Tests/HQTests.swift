import Testing
@testable import COR

/// HQ roster management: **unit upgrades within a family**. An upgrade swaps the
/// platform of a deployed unit for a costlier sibling in the same shop category
/// while preserving the crew's veterancy, charging only the prestige the new
/// platform adds over the old. `HQSim` is noncopyable, so every value read by
/// `#expect` is hoisted into a local first.
struct HQTests {

	/// A single-unit German roster at tier 3 with plenty of prestige. The unit
	/// is `reset()` the way the engine stores roster units (full strength).
	private static func sim(_ unit: Unit, prestige: UInt16 = 5000, tier: UInt8 = 3) -> HQSim {
		HQSim(
			player: Player(country: .ger, type: .human, prestige: prestige, tier: tier),
			units: [16 of Unit](head: [modifying(unit) { u in u.reset() }], tail: .empty)
		)
	}

	/// The same single-unit roster wrapped in an `HQState` (cursor at slot 0).
	private static func state(_ unit: Unit) -> HQState {
		HQState(sim: sim(unit))
	}

	@Test func upgradesAreFamilySiblingsExcludingSelf() {
		let shop = Shop(country: .ger, tier: 3)
		let models = shop.upgrades(for: Unit(model: .leo1, country: .ger)).map(\.model)

		#expect(!models.contains(.leo1), "a unit cannot upgrade into itself")
		#expect(models.contains(.kf51), "the Leopard 1 should upgrade into the KF51")
		#expect(!models.contains(.regular), "tanks and infantry are different families")
	}

	@Test func tierLocksUpgradeOptions() {
		// The KF51 is tier 2, so at tier 0 the Leopard 1 has nowhere to go.
		let shop = Shop(country: .ger, tier: 0)
		let models = shop.upgrades(for: Unit(model: .leo1, country: .ger)).map(\.model)
		#expect(models.isEmpty)
	}

	@Test func supplyHasNoUpgrades() {
		let shop = Shop(country: .ger, tier: 3)
		#expect(shop.upgrades(for: Unit(model: .truck, country: .ger)).isEmpty)
	}

	@Test func upgradePreservesVeterancyAndChargesFullCost() {
		let veteran = modifying(Unit(model: .leo1, country: .ger)) { u in
			u.lvl = 3
			u.kills = 7
		}
		let cost = veteran.upgradeCost(to: .kf51)
		// The full cost of the resulting unit — the new platform at lvl 3 — not
		// the difference over the Leopard 1.
		#expect(cost == Unit(model: .kf51, country: .ger).lvl(3).cost)

		var sim = Self.sim(veteran)
		let events = sim.reduce(.upgrade(0, .kf51))

		let model = sim.units[0].model
		let lvl = sim.units[0].lvl
		let kills = sim.units[0].kills
		let prestige = sim.player.prestige
		let spawned = events.contains { event in
			if case .spawn(let uid) = event { uid == 0.uid } else { false }
		}

		#expect(model == .kf51, "the platform should change")
		#expect(lvl == 3, "veterancy must carry across the upgrade")
		#expect(kills == 7, "the kill count must carry across the upgrade")
		#expect(prestige == 5000 - cost, "prestige is charged the full new-unit cost")
		#expect(spawned, "the sprite is refreshed for the new platform")
	}

	@Test func upgradeRejectedWithoutPrestige() {
		let leo1 = Unit(model: .leo1, country: .ger)
		let cost = leo1.upgradeCost(to: .kf51)
		var sim = Self.sim(leo1, prestige: cost - 1)
		let events = sim.reduce(.upgrade(0, .kf51))

		let model = sim.units[0].model
		let prestige = sim.player.prestige
		#expect(model == .leo1, "the upgrade must not apply when unaffordable")
		#expect(prestige == cost - 1, "no prestige is spent on a rejected upgrade")
		#expect(events.isEmpty)
	}

	@Test func upgradeRejectedAcrossFamilies() {
		// Infantry is a different family — not a legal target for a tank.
		var sim = Self.sim(Unit(model: .leo1, country: .ger))
		let events = sim.reduce(.upgrade(0, .regular))

		let model = sim.units[0].model
		let prestige = sim.player.prestige
		#expect(model == .leo1)
		#expect(prestige == 5000, "an illegal upgrade spends nothing")
		#expect(events.isEmpty)
	}

	// MARK: Input bindings

	@Test func cUpgradesSelectedUnitAndKeepsSelection() {
		var state = Self.state(Unit(model: .leo1, country: .ger))
		_ = state.apply(.action(.a)) // select slot 0 (cursor starts at .zero)
		let reaction = state.apply(.action(.c))

		var opened = false
		if case .events(let events) = reaction,
		   case .upgrade(let uid)? = events.first, uid == 0.uid { opened = true }
		let stillSelected = state.ui.selected == 0.uid

		#expect(opened, "`.c` opens the upgrade menu for the selected unit")
		#expect(stillSelected, "the unit stays selected after opening the menu")
	}

	@Test func cIsInertOverAnUnselectedUnit() {
		var state = Self.state(Unit(model: .leo1, country: .ger))
		let reaction = state.apply(.action(.c)) // cursor on the unit, nothing selected

		var inert = false
		if case .events(let events) = reaction, events.isEmpty { inert = true }
		#expect(inert, "upgrades are offered only for the selected unit")
	}

	@Test func cOpensShopOnAnEmptySlot() {
		var state = Self.state(Unit(model: .leo1, country: .ger))
		_ = state.apply(.direction(.right)) // move to the empty slot 1
		let reaction = state.apply(.action(.c))

		var shop = false
		if case .events(let events) = reaction, case .shop? = events.first { shop = true }
		#expect(shop, "`.c` still opens the purchase shop on an empty slot")
	}

	@Test func dSellsSelectedUnitAndClearsSelection() {
		var state = Self.state(Unit(model: .leo1, country: .ger))
		_ = state.apply(.action(.a)) // select slot 0
		let reaction = state.apply(.action(.d))

		var sold = false
		if case .action(.sell(let i)) = reaction, i == 0 { sold = true }
		let cleared = state.ui.selected == .none

		#expect(sold, "`.d` sells the selected unit")
		#expect(cleared, "selling clears the selection")
	}

	@Test func dIsInertWithoutSelection() {
		var state = Self.state(Unit(model: .leo1, country: .ger))
		let reaction = state.apply(.action(.d))

		var inert = false
		if case .events(let events) = reaction, events.isEmpty { inert = true }
		#expect(inert, "`.d` does nothing when no unit is selected")
	}
}
