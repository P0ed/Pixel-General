import SpriteKit
import AVFoundation

enum TacticalEvent: Hashable {
	case spawn(UID)
	case move(UID, XY, XY)
	case attack(UID, UID, UInt8, UInt8)
	case resupply(UID)
	case nextDay
	case shop
	case menu
	case gameOver
	case none
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
		case let .move(uid, a, b): await processMove(uid: uid, from: a, to: b)
		case let .attack(src, dst, dmg, hp): await processAttack(src: src, dst: dst, dmg: dmg, hp: hp)
		case let .resupply(id): processResupply(id: id)
		case .nextDay: nodes?.updateUnits(state)
		case .shop: processShop()
		case .menu: processMenu()
		case .gameOver: restartGame(state: state)
		case .none: break
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

	func processMove(uid: UID, from a: XY, to b: XY) async {
		guard let nodes, let unit = nodes.units[uid.index] else { return }

		let za = nodes.map.zPosition(at: a)
		let zb = nodes.map.zPosition(at: b)
//		unit.isHidden = !state.player.visible[a]
//			|| (state.cargo[uid.index] != -1 && !state.units[uid.index][.transport])
		unit.position = state.map.point(at: a)
		unit.zPosition = max(za, zb)

		nodes.sounds.mov.play()
		await unit.run(.move(
			to: state.map.point(at: b),
			duration: CGFloat(a.distance(to: b)) * 0.033
		))
		unit.zPosition = zb
		unit.isHidden = !state.isVisible(uid)
	}

	func processAttack(src: UID, dst: UID, dmg: UInt8, hp: UInt8) async {
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

	func processResupply(id: UID) {
		nodes?.units[id.index]?.update(hp: state.units[id.index].hp)
	}

	func processShop() {
		guard let building = state.buildings[state.cursor],
			  building.country == state.country,
			  state.unitAt(state.cursor) == nil
		else { return }

		let xy = state.cursor
		let items = state.shopUnits(at: xy).map { template in
			MenuItem<TacticalState>.close(
				icon: template.imageName,
				status: template.status,
				action: "\(template.cost) / \(state.player.prestige) ><",
				update: { state in state.buy(template, at: xy) }
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
