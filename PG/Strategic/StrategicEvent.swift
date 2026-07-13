import SpriteKit
import COR

extension StrategicNodes {

	func process(_ event: StrategicEvent, _ state: borrowing StrategicState) async {
		switch event {
		case .attack(let xy): processAttack(xy)
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

	private func processAttack(_ xy: XY) {
		guard let scene else { return }
		core.store(scene.state.sim)
		core.startCampaignBattle(at: xy)
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
				.space,
				.space,
				.load { [weak scene] in scene?.saveState() },
				.space,
			]
		))
	}
}
