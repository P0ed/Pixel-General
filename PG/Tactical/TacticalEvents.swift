import SpriteKit
import AVFoundation

enum TacticalEvent: Hashable {
	case spawn(UID)
	case move(UID, XY)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case shop
	case menu
	case end
}

extension TacticalScene {

	func process(events: [TacticalEvent]) async {
		for e in events { await process(e) }
	}

	func respawn() {
		state.units.forEach { i, u in processSpawn(uid: i.uid) }
	}
}

private extension TacticalScene {

	func process(_ event: TacticalEvent) async {
		switch event {
		case let .spawn(uid): processSpawn(uid: uid)
		case let .move(uid, xy): await processMove(uid, xy)
		case let .fire(src, dst, dmg, hp): await processFire(src: src, dst: dst, dmg: dmg, hp: hp)
		case let .update(id): update(id: id)
		case .shop: processShop()
		case .menu: processMenu()
		case .end: restartGame(state: state)
		}
	}

	func processSpawn(uid: UID) {
		guard let nodes else { return }

		let sprite = state.units[uid.index].sprite
		let xy = state.position[uid.index]
		sprite.position = state.map.point(at: xy)
		sprite.zPosition = nodes.map.zPosition(at: xy)
		sprite.isHidden = !state.isVisible(uid)
		addUnit(uid, node: sprite)
	}

	func processMove(_ uid: UID, _ xy: XY) async {
		guard let nodes, let unit = nodes.units[uid.index] else { return }

		let p = state.map.point(at: xy)
		let z = nodes.map.zPosition(at: xy)
		unit.zPosition = max(unit.zPosition, z)

		if !unit.isHidden {
			nodes.sounds.mov.play()
			let d = (unit.position - p).length / 640.0
			await unit.run(.move(to: p, duration: d))
		} else {
			unit.position = p
		}
		unit.zPosition = nodes.map.zPosition(at: xy)
		unit.isHidden = !state.isVisible(uid)
	}

	func processFire(src: UID, dst: UID, dmg: UInt8, hp: UInt8) async {
		nodes?.units[src.index]?.showSight(for: 0.47)
		await run(.wait(forDuration: 0.22))
		nodes?.units[dst.index]?.showSight(for: 0.47 - 0.22)
		await run(.wait(forDuration: 0.22))

		if hp > 0 {
			if dmg > 0 {
				nodes?.sounds.boomM.play()
			} else {
				nodes?.sounds.boomS.play()
			}
			nodes?.units[dst.index]?.update(hp: hp)
		} else {
			nodes?.sounds.boomL.play()
			removeUnit(dst)
		}
	}

	func update(id: UID) {
		nodes?.units[id.index]?.update(hp: state.units[id.index].hp)
	}

	func processShop() {
		guard let building = state.buildings[state.cursor],
			  building.country == state.country,
			  state.unitAt(state.cursor) == nil
		else { return }

		let xy = state.cursor
		let items = state.shopUnits(at: xy).enumerated().map { i, template in
			MenuItem<TacticalState>.close(
				icon: template.imageName,
				status: template.status,
				action: "\(template.cost) / \(state.player.prestige) ><",
				update: { state in state.buy(i, at: xy) }
			)
		}

		if !items.isEmpty { show(MenuState(items: items)) }
	}

	func processMenu() {
		guard case .none = menuState else { return show(.none) }

		var vol: Int {
			let v = audioEngine.mainMixerNode.outputVolume
			return v < 0.1 ? 0 : v < 0.7 ? 1 : 2
		}
		let toggleVol = { [audioEngine] in
			switch vol {
			case 0: audioEngine.mainMixerNode.outputVolume = 0.5
			case 1: audioEngine.mainMixerNode.outputVolume = 1.0
			default: audioEngine.mainMixerNode.outputVolume = 0.0
			}
		}

		show(MenuState(
			items: [
				.close(icon: "Start", status: "End turn") { state in
					state.endTurn()
				},
				.close(icon: "Save", status: "Save") { state in
					core.store(tactical: state, auto: false)
				},
				.close(icon: "Load", status: "Load") { [weak self] state in
					core.load(auto: false)
					_ = self?.view?.present(core.state)
				},
				.close(icon: "HQ", status: "HQ") { [weak self] state in
					self?.restartGame(state: state)
				},
				MenuItem(icon: "S", status: "Prestige: \(state.player.prestige)", update: { _, m in
					m
				}),
				MenuItem(icon: "Sound\(vol)", status: "Volume", update: { _, menu in
					modifying(menu) { menu in
						toggleVol()
						menu.items[5].icon = "Sound\(vol)"
					}
				})
			]
		))
	}

	private func restartGame(state: borrowing TacticalState) {
		core.complete(tactical: state)
		view?.present(core.state)
	}
}
