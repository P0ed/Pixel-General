import SpriteKit
import AVFoundation

enum TacticalEvent {
	case spawn(UID)
	case move(UID, XY)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case shop
	case menu
	case end
}

extension TacticalNodes {

	func process(_ event: TacticalEvent, _ state: borrowing TacticalState) async {
		switch event {
		case let .spawn(uid): processSpawn(uid, state)
		case let .move(uid, xy): await processMove(uid, xy, state)
		case let .fire(src, dst, dmg, hp): await processFire(src: src, dst: dst, dmg: dmg, hp: hp)
		case let .update(id): update(id, state)
		case .shop: processShop(state)
		case .menu: processMenu(state)
		case .end: restartGame(state)
		}
	}
}

private extension TacticalNodes {

	func processSpawn(_ uid: UID, _ state: borrowing TacticalState) {
		let sprite = state.units[uid.index].sprite
		let xy = state.position[uid.index]
		sprite.position = state.map.point(at: xy)
		sprite.zPosition = map.zPosition(at: xy)
		sprite.isHidden = !state.isVisible(uid)
		addUnit(uid, node: sprite)
	}

	func processMove(_ uid: UID, _ xy: XY, _ state: borrowing TacticalState) async {
		guard let unit = units[uid.index] else { return }

		let p = state.map.point(at: xy)
		let z = map.zPosition(at: xy)
		unit.zPosition = max(unit.zPosition, z)

		if !unit.isHidden {
			sounds.mov.play()
			let d = (unit.position - p).length / 640.0
			await unit.run(.move(to: p, duration: d))
		} else {
			unit.position = p
		}
		unit.zPosition = map.zPosition(at: xy)
		unit.isHidden = !state.isVisible(uid)
	}

	func processFire(src: UID, dst: UID, dmg: UInt8, hp: UInt8) async {
		units[src.index]?.showSight(for: 0.47)
		await scene?.run(.wait(forDuration: 0.22))
		units[dst.index]?.showSight(for: 0.47 - 0.22)
		await scene?.run(.wait(forDuration: 0.22))

		if hp > 0 {
			if dmg > 0 {
				sounds.boomM.play()
			} else {
				sounds.boomS.play()
			}
			units[dst.index]?.update(hp: hp)
		} else {
			sounds.boomL.play()
			removeUnit(dst)
		}
	}

	func update(_ id: UID, _ state: borrowing TacticalState) {
		units[id.index]?.update(hp: state.units[id.index].hp)
	}

	func processShop(_ state: borrowing TacticalState) {
		guard let building = state.buildings[state.cursor],
			  building.country == state.country,
			  state.unitAt(state.cursor) == nil
		else { return }

		let xy = state.cursor
		let items = state.shopUnits(at: xy).enumerated().map { i, template in
			MenuItem<TacticalAction>.close(
				icon: template.imageName,
				status: .init(
					text: template.status,
					action: .init("\(template.cost) / \(state.player.prestige) ><")
				),
				action: .purchase(i, xy)
			)
		}

		if !items.isEmpty { scene?.show(MenuState(items: items)) }
	}

	func processMenu(_ state: borrowing TacticalState) {
		guard let scene, case .none = scene.menuState else {
			return _ = scene?.show(.none)
		}

		var vol: Int {
			let v = scene.audioEngine.mainMixerNode.outputVolume
			return v < 0.1 ? 0 : v < 0.7 ? 1 : 2
		}
		let toggleVol = { [audioEngine = scene.audioEngine] in
			switch vol {
			case 0: audioEngine.mainMixerNode.outputVolume = 0.5
			case 1: audioEngine.mainMixerNode.outputVolume = 1.0
			default: audioEngine.mainMixerNode.outputVolume = 0.0
			}
		}

		scene.show(MenuState(
			items: [
				.close(icon: "Start", status: "End turn", action: .end),
				.close(icon: "Save", status: "Save") { [weak scene] _ in
					if let scene {
						core.store(scene.state, auto: false)
					}
				},
				.close(icon: "Load", status: "Load") { _ in
					core.load(auto: false)
					present(.make(core.state))
				},
				.close(icon: "HQ", status: "HQ") { [weak scene] _ in
					if let scene { restartGame(scene.state) }
				},
				MenuItem(
					icon: "S",
					status: .init(text: "Prestige: \(state.player.prestige)"),
					update: id
				),
				MenuItem(icon: "Sound\(vol)", status: .init(text: "Volume"), update: { menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[5].icon = "Sound\(vol)"
					}
				})
			]
		))
	}

	private func restartGame(_ state: borrowing TacticalState) {
		core.complete(state)
		present(.make(core.state))
	}
}
