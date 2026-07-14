import SpriteKit
import COR

extension StrategicNodes {

	func process(_ event: StrategicEvent, _ state: borrowing StrategicState) async {
		switch event {
		case .attack(let slot, let xy): processAttack(xy, by: slot)
		case .build, .move, .found, .endTurn: persist()
		}
	}

	func present(_ intent: StrategicPresentationIntent, _ state: borrowing StrategicState) async {
		switch intent {
		case .army(let slot): processArmy(slot)
		case .menu: processMenu(state)
		}
	}

	/// Persists a sim mutation the reducer already applied (march, muster,
	/// fortify).
	private func persist() {
		guard let scene else { return }
		core.store(scene.state.sim)
		core.save()
	}

	private func processAttack(_ xy: XY, by slot: Int) {
		guard let scene else { return }
		core.store(scene.state.sim)
		if settings.campaignAutoresolve {
			core.autoResolveCampaignBattle(at: xy, by: slot)
		} else {
			core.startCampaignBattle(at: xy, by: slot)
		}
		core.save()
		view.present(.auto)
	}

	private func processArmy(_ slot: Int) {
		guard let scene else { return }
		core.store(scene.state.sim)
		core.openArmy(slot)
		core.save()
		view.present(.auto)
	}

	private func processMenu(_ state: borrowing StrategicState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.showMenu(.none)
		}

		scene.showMenu(MenuState(
			items: [
				.close(icon: .start, status: "Next turn", action: .endTurn),
				.space,
				.load { [weak scene] in scene?.saveState() },
				.confirm(icon: .HQ, status: "Abandon campaign") { [weak scene] in
					guard let scene else { return }
					core = .new(country: scene.state.sim.player.country)
					core.save()
					view.present(.auto)
				},

				MenuItem(
					icon: .toggle4(settings.campaignAutoresolve ? 3 : 0),
					status: .init(text: "Battle autoresolve"),
					update: { menu in
						modifying(menu) { menu in
							settings.toggleCampaignAutoresolve()
							menu.items[4].icon = .toggle4(settings.campaignAutoresolve ? 3 : 0)
						}
					}
				),
				.space, .space, .space,
			]
		))
	}
}
